class IllustrationsController < ApplicationController
  before_action :set_illustration, only: %i[ show edit update destroy ]

  # GET /illustrations or /illustrations.json
  def index
    @illustrations = Illustration.all
  end

  # GET /illustrations/1 or /illustrations/1.json
  def show
  end

  # GET /illustrations/new
  def new
    @illustration = Illustration.new
  end

  # GET /illustrations/1/edit
  def edit
  end

  # POST /illustrations or /illustrations.json
  def create
    images = params[:illustration][:images]
    name = params[:illustration][:illustrator_name]
  
    if images.present?
      images.each do |img|
        # 1. 新しいレコードのインスタンスを作る
        @illustration = Illustration.new(illustrator_name: name, image: img)
  
        # 2. 画像ファイルから Exif 情報を解析して撮影日時を取得
        begin
          image_data = MiniMagick::Image.new(img.tempfile.path)
          # Exifの 'DateTimeOriginal' (撮影日時) を取得
          exif_date = image_data.exif['DateTimeOriginal']
          
          if exif_date
            # "2024:01:01 12:00:00" という文字列を Rails の日時形式に変換
            @illustration.shot_at = DateTime.strptime(exif_date, '%Y:%m:%d %H:%M:%S')
          end
        rescue => e
          logger.error "Exifの取得に失敗しました: #{e.message}"
          # 取得に失敗しても画像自体は保存できるように、エラーは握りつぶすかデフォルト値を設定
        end
  
        # 3. 保存
        @illustration.save
      end
      redirect_to illustrations_path, notice: "アップロードが完了しました！"
    else
      # 画像がない場合の処理（省略）
    end
  end

  # PATCH/PUT /illustrations/1 or /illustrations/1.json
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

  # DELETE /illustrations/1 or /illustrations/1.json
  def destroy
    @illustration.destroy!

    respond_to do |format|
      format.html { redirect_to illustrations_path, notice: "Illustration was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_illustration
      @illustration = Illustration.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def illustration_params
      # images: [] とすることで、配列形式（複数画像）のデータを受け取れるようにします
      params.require(:illustration).permit(:illustrator_name, :shot_at, images: [])
    end
end
