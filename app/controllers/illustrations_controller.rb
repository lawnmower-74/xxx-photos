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
    if params[:illustration].blank? || params[:illustration][:image].blank?
      render json: { error: "画像を選択してください" }, status: :unprocessable_entity
      return
    end
  
    @illustration = Illustration.new(illustration_params)
  
    # 1. まずは一旦保存する（これでファイルがstorage/の中に書き込まれる）
    if @illustration.save
      # 2. 保存成功後、ファイルを開いて日時を抽出する
      begin
        @illustration.image.open do |file|
          # exiftoolで日時を取得
          output = `exiftool -s3 -d "%Y-%m-%d %H:%M:%S" -DateTimeOriginal -CreateDate "#{file.path}"`
          times = output.split("\n").map(&:strip).reject(&:empty?)
          
          if times.any?
            # 3. 日時が取れたら、update_column でその値だけをDBに書き込む
            # (update_columnを使うとバリデーションをスキップして高速に更新できます)
            @illustration.update_column(:shot_at, Time.zone.parse(times.first))
          end
        end
      rescue => e
        logger.error "Exiftool抽出失敗: #{e.message}"
        # 抽出に失敗しても、アップロード自体は成功しているのでそのまま進む
      end

      # 4. 最終的な結果をJSONで返す
      render json: {
        url: url_for(@illustration.image),
        illustrator_name: @illustration.illustrator_name,
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
