class IllustrationsController < ApplicationController
  before_action :set_illustration, only: %i[ show edit update ]

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
    
    # 類似画像（重複候補）の抽出
    @similar_illustrations = calculate_similar_illustrations(@illustrator.id)
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
      safe_params = illustration_params

      # 入力値チェック
      if safe_params[:image].blank? || safe_params[:illustrator_name].blank?
        return render json: { error: "フォームに入力してください" }, status: :unprocessable_entity
      end

      # イラストレーター（フォルダ）検索／なければ新規作成
      illustrator = Illustrator.find_or_create_illustrator_safely!(safe_params[:illustrator_name])
    
      # イラストレーターの子要素として画像を紐づけ
      @illustration = illustrator.illustrations.build(image: safe_params[:image])
    
      # アップロード（DB・Storageともに）
      if @illustration.save
        AnalyzeIllustrationJob.perform_later(@illustration.id)
    
        render json: { message: "アップロード完了", id: @illustration.id }, status: :created
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
    # 削除実行
    if ids.present? && Illustration.where(id: ids).destroy_all

      # 削除後（更新後）の全画像を取得
      @illustrator = Illustrator.find_by!(name: params[:illustrator_name])
      
      # 上記から類似画像を再計算
      @similar_illustrations = calculate_similar_illustrations(@illustrator.id)
  
      html = render_to_string(
        partial: 'illustrations/similar_section',
        formats: [:html],
        locals: { 
          similar_illustrations: @similar_illustrations
        }
      )

      render json: { 
        message: "一括削除に成功しました", 
        html: html 
      }, status: :ok
    else
      render json: { error: "削除する項目が選択されていないか、失敗しました" }, status: :unprocessable_entity
    end
  end

  def destroy
    @illustrator = Illustrator.find_by!(name: params[:id])
    @illustrator.destroy
    render json: { message: "削除しました" }, status: :ok
  end

  # ======================================================================
  # 非同期Job（撮影日時抽出・類似判定用データ生成）の完了チェック
  # ======================================================================
  def check_jobs_status
    ids = params.permit(ids: [])[:ids] || []

    if ids.empty?
      return render json: { completed: true, completed_count: 0, total_count: 0 }, status: :ok
    end

    total_count = ids.size
    completed_count = Illustration.where(id: ids).where.not(fingerprint: nil).count

    is_completed = completed_count == total_count

    render json: {
      completed: is_completed,
      completed_count: completed_count,
      total_count: total_count
    }, status: :ok
  end

  
  private

  def set_illustration
    @illustration = Illustration.find(params[:id])
  end

  def illustration_params
    params.require(:illustration).permit(:illustrator_name, :image)
  end

  # ==========================================
  # 類似画像（重複候補）の抽出
  # ==========================================
  def calculate_similar_illustrations(illustrator_id)
    # -----------------------------------------
    # 類似のしきい値（この値以下を類似と判定）
    # -----------------------------------------
    threshold = 5

    # データベース上で同一イラストレーター内の画像同士を比較し、ハミング距離が閾値以下の画像IDを取得する
    sql = <<~SQL
      SELECT DISTINCT i1.id
      FROM illustrations i1
      INNER JOIN illustrations i2 
        ON i1.illustrator_id = i2.illustrator_id
        AND i1.id != i2.id
      WHERE i1.illustrator_id = :illustrator_id
        AND i1.fingerprint IS NOT NULL
        AND i2.fingerprint IS NOT NULL
        AND BIT_COUNT(CAST(i1.fingerprint AS UNSIGNED) ^ CAST(i2.fingerprint AS UNSIGNED)) <= :threshold
    SQL

    similar_ids = Illustration.find_by_sql([sql, { illustrator_id: illustrator_id, threshold: threshold }]).map(&:id)

    direction = params[:sort] == 'asc' ? :asc : :desc

    Illustration.where(id: similar_ids)
                .includes(image_attachment: :blob)
                .order(shot_at: direction)
  end
end
