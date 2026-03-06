class IllustrationsController < ApplicationController
  before_action :set_illustration, only: %i[ show edit update destroy ]

  def index
    # ※イラストレーター = フォルダ
    @illustrators = Illustrator.all.includes(
      # サムネで表示するため含める
      cover_illustration: { image_attachment: :blob }, # カバー画像のパス
      latest_illustration: { image_attachment: :blob } # 最新画像のパス
    )
  end

  def show
  end

  # ==========================================
  # フォルダ内アクセス（画像一覧表示）
  # ==========================================
  def show_by_illustrator
    @illustrator = Illustrator.find_by!(name: params[:name])
    direction = params[:sort] == 'asc' ? :asc : :desc
    
    # 一覧に表示する画像の抽出
    @illustrations = @illustrator.illustrations
                                  .includes(image_attachment: :blob)
                                  .order(shot_at: direction)
    
    # -----------------------------------------
    # 類似画像（重複候補）の抽出
    # -----------------------------------------
    candidates = @illustrations.select { |i| i.fingerprint.present? }
    
    similar_ids = []

    # -----------------------------------------
    # 類似のしきい値（この値以下を類似と判定）
    # -----------------------------------------
    threshold = 5

    # 一枚同士で比較
    candidates.each_with_index do |img_a, index|
    
      # 画像A を 64bit 正整数に変換
      hash_a = img_a.fingerprint.to_i & 0xFFFFFFFFFFFFFFFF
    
      # 画像A 以降の画像を一枚抽出
      candidates[(index + 1)..-1].each do |img_b|
        # 画像B も 64bit 正整数に変換
        hash_b = img_b.fingerprint.to_i & 0xFFFFFFFFFFFFFFFF
        
        # 二つの値を重ねると数値の違うところだけが 1 として浮かび上がる。その数をカウント（= ハミング距離）
        distance = (hash_a ^ hash_b).to_s(2).count("1")
    
        # ハミング距離がしきい値以下であれば「類似」と判定
        if distance <= threshold
          similar_ids << img_a.id
          similar_ids << img_b.id
        end
      end
    end

    # 重複候補があれば、それらだけを抽出
    @similar_illustrations = @illustrator.illustrations
                                        .where(id: similar_ids.uniq)
                                        .includes(image_attachment: :blob)
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
    # ----------------------------------------
    # デッドロック対策（リトライ）
    # ----------------------------------------
    retries = 0
    max_retries = 3      # 無限ループ防止
    sleep_interval = 0.1 # リトライ間隔

    begin
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
        # 「撮影日時」の抽出・保存を非同期で実行
        ExtractExifJob.perform_later(@illustration.id)

        # # 「見た目の特徴値（ハッシュ）」の計算・保存を非同期で実行
        GenerateFingerprintJob.perform_later(@illustration.id)
    
        render json: { message: "アップロード完了" }, status: :created
      else
        render json: { error: @illustration.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    
    rescue ActiveRecord::Deadlocked => e
      # デッドロックが発生した場合はリトライ
      if retries < max_retries
        retries += 1
        Rails.logger.warn "デッドロック検知。リトライします（#{retries}回目）: #{e.message}"
        sleep(sleep_interval)
        retry
      else
        raise e # リトライしてもダメならエラーとして投げる
      end
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
