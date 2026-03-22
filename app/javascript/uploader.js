export const ImageUploader = {
  async bulkUpload(images, illustratorName, csrfToken, onProgress) {

    // 計測用 臨時追加 ========================================
    const startTime = performance.now();
    // =======================================================

    // 進捗管理用
    const totalImages = images.length;
    let completedCount = 0;
    let errorCount = 0;
    let failedImages = [];
    
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

    
    // 計測用 臨時追加 ===========================================================================
    const endTime = performance.now();
    const durationInSeconds = ((endTime - startTime) / 1000).toFixed(2);
    
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("【全アップロードリクエスト完了】");
    console.log(`完了表示までの所要時間: ${durationInSeconds} 秒`);
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    // =======================================================================================

    return { 
      successCount: completedCount, 
      errorCount, 
      failedImages, 
      isAllSuccess: errorCount === 0 
    };
  }
};