class IllustratorsController < ApplicationController
  def destroy
    @illustrator = Illustrator.find_by!(name: params[:name])
    
    # 紐づく画像ごと削除
    if @illustrator.destroy
      render json: { status: 'success', message: '削除しました' }, status: :ok
    else
      render json: { status: 'error', message: '削除に失敗しました' }, status: :unprocessable_entity
    end
  end
end