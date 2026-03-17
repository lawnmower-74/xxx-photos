export const FolderManager = {
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
  }
};