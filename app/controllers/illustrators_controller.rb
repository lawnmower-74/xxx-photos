class IllustratorsController < ApplicationController
  # ※イラストレーター = フォルダ

  # フォルダ削除
  def destroy
    @illustrator = Illustrator.find_by!(name: params[:name])
    
    # 紐づく画像ごと削除
    if @illustrator.destroy
      render json: { status: 'success', message: '削除しました' }, status: :ok
    else
      render json: { status: 'error', message: '削除に失敗しました' }, status: :unprocessable_entity
    end

  end

  # アルバムカバーの更新
  def set_cover
    @illustrator = Illustrator.find_by!(name: params[:name])

    # 画像IDをカバーIDに指定
    if @illustrator.update(cover_illustration_id: params[:image_id])
      render json: { status: 'success', message: 'カバー画像を更新しました' }
    else
      render json: { status: 'error', message: '更新に失敗しました' }, status: :unprocessable_entity
    end
  end
end