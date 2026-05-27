export const ImageUploader = {
  async bulkUpload(images, illustratorName, csrfToken, onProgress, onJobProgress) {
    // 進捗管理用
    const totalImages = images.length;
    let completedCount = 0;
    let errorCount = 0;
    let failedImages = [];
    let uploadedIds = [];
    
    // ------------------
    // 並列数
    // ------------------
    const CONCURRENCY_LIMIT = 3;

    const ImagesQueue = [...images];

    const uploadSingleImage = async (image) => {
      const formData = new FormData();
      formData.append("illustration[illustrator_name]", illustratorName);
      formData.append("illustration[image]", image);

      try {
        const response = await fetch("/illustrations", {
          method: "POST",
          headers: { "X-CSRF-Token": csrfToken },
          body: formData
        });

        if (!response.ok) throw new Error('アップロード失敗'); // -> catchへ

        // ※非同期Jobの完了チェック用にアップロードしたものはここで追加
        const data = await response.json();
        if (data.id) {
          uploadedIds.push(data.id);
        }

        completedCount++;
        
      } catch (err) {
        console.error("アップロード失敗: ", err);
        errorCount++;
        failedImages.push(image.name);

      } finally {
        // 進捗をView側に報告
        if (onProgress) {
          onProgress({ completedCount, errorCount, failedImages, totalImages });
        }
      }
    };

    // 画像がなくなるまで取り出してアップロード処理へ
    const worker = async () => {
      while (ImagesQueue.length > 0) {
        const image = ImagesQueue.shift(); // 行列の先頭から1枚取り出す
        if (image) await uploadSingleImage(image);
      }
    };

    // 指定した数だけワーカーを同時に起動
    const workers = [];
    for (let i = 0; i < Math.min(CONCURRENCY_LIMIT, totalImages); i++) {
      workers.push(worker());
    }

    // すべてのワーカーの処理が終わるのを待つ
    await Promise.all(workers);

    // ===========================================================================================
    // 全件アップロードが完了したら非同期Job（撮影日時抽出・類似判定用データ生成）が完了したかをチェック
    // ===========================================================================================
    let jobsCompleted = false;

    if (uploadedIds.length > 0) {
      const MAX_POLLING_MS = 120000; // タイムアウトの制限時間（2分）
      const pollingDeadline = Date.now() + MAX_POLLING_MS;

      while (Date.now() < pollingDeadline) {
        try {
          const response = await fetch("/illustrations/check_jobs_status", {
            method: "POST",
            headers: {
              "X-CSRF-Token": csrfToken,
              "Content-Type": "application/json"
            },
            body: JSON.stringify({ ids: uploadedIds })
          });

          if (!response.ok) throw new Error('ジョブ状態の確認に失敗'); // -> catchへ

          const statusData = await response.json();

          // JSONが戻るたびにViewにJobの進捗を報告
          if (onJobProgress) {
            onJobProgress({ completed: statusData.completed_count, total: statusData.total_count });
          }

          if (statusData.completed) {
            jobsCompleted = true;
            break; // 全Job完了したらチェックループを終了
          }

        } catch (err) {
          console.error("ジョブ状態の確認に失敗:", err);
        }

        // 2秒待機してから再チェック
        await new Promise(resolve => setTimeout(resolve, 2000));
      }

      // タイムアウト時に呼び出し元へ通知
      if (!jobsCompleted && onJobProgress) {
        onJobProgress({ completed: null, total: null, timedOut: true });
      }
    }

    return { 
      successCount: completedCount, 
      errorCount, 
      failedImages, 
      isAllSuccess: errorCount === 0,
      jobsCompleted,
    };
  }
};