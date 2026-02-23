class IllustrationsController < ApplicationController
  before_action :set_illustration, only: %i[ show edit update destroy ]

  # GET /illustrations or /illustrations.json
  def index
    @illustrators = Illustrator.all
  end

  # GET /illustrations/1 or /illustrations/1.json
  def show
  end

  def show_by_illustrator
    # URLの :name パラメータから作者を特定
    @illustrator = Illustrator.find_by!(name: params[:name])
    
    # ソート順の決定
    direction = params[:sort] == 'asc' ? :asc : :desc
    
    # その作者に紐づく画像だけを取得
    @illustrations = @illustrator.illustrations
                                  .with_attached_image
                                  .order(shot_at: direction)
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
    # 1. バリデーション（画像と名前があるか）
    if params[:illustration].blank? || params[:illustration][:image].blank? || params[:illustration][:illustrator_name].blank?
      return render json: { error: "画像とイラストレーター名を入力してください" }, status: :unprocessable_entity
    end
  
    # 2. イラストレーターを探す、または新規作成する (find_or_create_by)
    illustrator = Illustrator.find_or_create_by!(name: params[:illustration][:illustrator_name])
  
    # 3. イラストレーターに紐付けてイラストを作成
    @illustration = illustrator.illustrations.build(image: params[:illustration][:image])
  
    if @illustration.save
      # 4. 前に作った exiftool の日時抽出処理
      begin
        @illustration.image.open do |file|
          output = `exiftool -s3 -d "%Y-%m-%d %H:%M:%S" -DateTimeOriginal -CreateDate "#{file.path}"`
          times = output.split("\n").map(&:strip).reject(&:empty?)
          @illustration.update_column(:shot_at, Time.zone.parse(times.first)) if times.any?
        end
      rescue => e
        logger.error "Exiftool抽出失敗: #{e.message}"
      end
  
      render json: {
        url: url_for(@illustration.image),
        illustrator_name: illustrator.name, # ここは関連から取得
        shot_at: @illustration.shot_at&.strftime("%Y-%m-%d %H:%M")
      }, status: :created
    else
      render json: { error: @illustration.errors.full_messages.join(", ") }, status: :unprocessable_entity
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
      # JSからは1枚ずつ届くので、images: [] ではなく image 単体で受け取る形にします
      params.require(:illustration).permit(:illustrator_name, :image)
    end

    # Exifから日時を抽出
    def read_shot_at(image)
      begin
        # Active Storageの添付ファイルを一時ファイルとして開く
        image.open do |file|
          # exiftoolを実行 (-s3で値のみ取得)
          # 撮影日時(DateTimeOriginal)がなければ作成日時(CreateDate)を取得
          output = `exiftool -s3 -d "%Y-%m-%d %H:%M:%S" -DateTimeOriginal -CreateDate "#{file.path}"`
          
          # 1行ずつ結果を見て、最初に見つかった日時を採用
          # outputには "2024-02-23 12:34:56\n2024-02-23 12:35:00" のように返ってくる
          times = output.split("\n").map(&:strip).reject(&:empty?)
          
          if times.any?
            return Time.zone.parse(times.first)
          end
        end
      rescue => e
        logger.error "Exiftool抽出失敗: #{e.message}"
      end
      nil # 何も取れなかったらnil
    end
end
