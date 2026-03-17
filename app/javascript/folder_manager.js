export const FolderManager = {
  // =============================
  // フォルダ削除
  // =============================
  async delete(name, csrfToken) {
    try {
      const response = await fetch(`/folders/${encodeURIComponent(name)}`, {
        method: "DELETE",
        headers: { 
          "X-CSRF-Token": csrfToken,
          "Content-Type": "application/json"
        }
      });

      return response.ok;

    } catch (err) {
      console.error("削除リクエストエラー: ", err);
      return false;
    }
  },

  // =============================
  // アルバムカバー更新
  // =============================
  async setCover(folderName, imageId, csrfToken) {
    try {
      const response = await fetch(`/folders/${encodeURIComponent(folderName)}/set_cover`, {
        method: "PATCH",
        headers: { 
          "X-CSRF-Token": csrfToken,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ image_id: imageId })
      });

      return response.ok;

    } catch (err) {
      console.error("カバー設定エラー: ", err);
      return false;
    }
  }
};