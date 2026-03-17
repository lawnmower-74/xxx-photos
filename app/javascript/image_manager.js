export const ImageManager = {
  async bulkDelete(ids, folderName, csrfToken) {
    try {
      const response = await fetch("/illustrations/bulk_destroy", {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ 
          ids: ids, // ※画像のID
          illustrator_name: folderName 
        })
      });

      if (response.ok) {
        return await response.json();

      } else {
        const errorData = await response.json().catch(() => ({}));
        throw new Error("削除に失敗しました: " + (errorData.error || "サーバーエラー"));
      }
    } catch (err) {
      console.error("削除リクエスト失敗:", err);
      throw err;
    }
  }
};