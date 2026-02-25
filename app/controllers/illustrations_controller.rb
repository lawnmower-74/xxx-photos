class IllustrationsController < ApplicationController
  before_action :set_illustration, only: %i[ show edit update destroy ]

  def index
    # ※イラストレーター = フォルダ
    @illustrators = Illustrator.all
  end

  def show
  end

  # ==========================================
  # フォルダ内アクセス（画像一覧表示）
  # ==========================================
  def show_by_illustrator
    @illustrator = Illustrator.find_by!(name: params[:name])
    direction = params[:sort] == 'asc' ? :asc : :desc
    
    @illustrations = @illustrator.illustrations
                                  .with_attached_image
                                  .order(shot_at: direction)
  end

  def new
    @illustration = Illustration.new
  end

  def edit
  end

  # ==========================================
  # アップロード処理
  # ==========================================
  def create
    # 入力値チェック
    if params[:illustration].blank? || params[:illustration][:image].blank? || params[:illustration][:illustrator_name].blank?
      return render json: { error: "フォームに入力してください" }, status: :unprocessable_entity
    end
  
    # イラストレーター（フォルダ）検索／なければ新規作成
    illustrator = Illustrator.find_or_create_by!(name: params[:illustration][:illustrator_name])
  
    # イラストレーターの子要素として画像を紐づけ
    @illustration = illustrator.illustrations.build(image: params[:illustration][:image])
  
    # アップロード（DB・Storageともに）
    if @illustration.save
      # EXIF情報から「撮影日時」抽出
      begin
        @illustration.image.open do |file|
          output = `exiftool -s3 -d "%Y-%m-%d %H:%M:%S" -DateTimeOriginal "#{file.path}"`
          times = output.split("\n").map(&:strip).reject(&:empty?)
          # 「撮影日時」用カラムを更新
          @illustration.update_column(:shot_at, Time.zone.parse(times.first)) if times.any?
        end
      rescue => e
        logger.error "「撮影日時」取得失敗: #{e.message}"
      end
  
      render json: { message: "アップロード成功" }, status: :created
    else
      render json: { error: @illustration.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def update
    respond_to do |format|
      if @illustration.update(illustration_params)
        format.html { redirect_to @illustration, notice: "Illustration was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @illustration }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @illustration.errors, status: :unprocessable_entity }
      end
    end
  end

  # ==========================================
  # 画像の個別／選択削除
  # ==========================================
  def bulk_destroy
    ids = params[:ids]
    if ids.present? && Illustration.where(id: ids).destroy_all
      render json: { message: "一括削除に成功しました" }, status: :ok
    else
      render json: { error: "削除する項目が選択されていないか、失敗しました" }, status: :unprocessable_entity
    end
  end

  def destroy
    @illustration = Illustration.find(params[:id])
    @illustration.destroy
    render json: { message: "削除しました" }, status: :ok
  end

  private
    def set_illustration
      @illustration = Illustration.find(params[:id])
    end

    def illustration_params
      params.require(:illustration).permit(:illustrator_name, :image)
    end
end
