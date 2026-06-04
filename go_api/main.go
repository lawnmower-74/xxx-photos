package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"math/bits"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

// ==========================================
// BK-Tree のデータ構造
// ==========================================
type BKNode struct {
	ID          int64
	Fingerprint uint64
	Children    map[int]*BKNode
}

type BKTree struct {
	Root *BKNode
}

// =============================================
// ハミング距離（XORした結果の1のビット数）を計算
// =============================================
func hammingDistance(a, b uint64) int {
	// 二つの値を重ねると数値の違うところだけが 1 として浮かび上がる。その数をカウント（= ハミング距離）
	return bits.OnesCount64(a ^ b)
}

// ==========================================
// BK-Treeにノードを挿入
// t: 指定イラストレーターのBK-Tree
// fp: 更新された画像
// ==========================================
func (t *BKTree) Insert(id int64, fp uint64) {
	// 新しいイラスト用のノードを作成
	node := &BKNode{
		ID:          id,
		Fingerprint: fp,
		Children:    make(map[int]*BKNode),
	}

	// 対象イラストレーターのBK-Treeがもしまだなければこれをルートとする（初回アップロード時など）
	if t.Root == nil {
		t.Root = node
		return
	}

	current := t.Root
	for {
		dist := hammingDistance(current.Fingerprint, fp)

		// その距離の枝にすでに画像がある場合、その画像と次のループで比較する（※1枝1ノードのため）
		if child, exists := current.Children[dist]; exists {
			current = child
		} else {
			current.Children[dist] = node
			return
		}
	}
}

// ==================================================================
// 類似判定
// t: 指定イラストレーターのBK-Tree
// fp: 調べたい画像
// ==================================================================
func (t *BKTree) Search(fp uint64, threshold int) []int64 {
	if t.Root == nil {
		return nil
	}

	var results []int64
	stack := []*BKNode{t.Root}  // チェックリスト（スタート地点としてルートを代入）

	for len(stack) > 0 {
		current := stack[len(stack)-1]  // 1. 調べたい画像（fp）と比較する画像を取得
		stack = stack[:len(stack)-1]    // 2. 1 をチェックリストから外す

		// 類似判定（1 と fp 間の距離を測定）
		dist := hammingDistance(current.Fingerprint, fp)
		if dist <= threshold {
			results = append(results, current.ID)
		}

		// -----------------------------------------------------------------------------------------------
		// dist ± threshold の範囲にある子ノードだけをチェックリストに追加（※ここで検索対象を大幅に限定できる）
		// -----------------------------------------------------------------------------------------------
		for childDist, child := range current.Children {
			if childDist >= dist-threshold && childDist <= dist+threshold {
				stack = append(stack, child)
			}
		}
	}
	return results
}

// ==========================================
// イラストレーターごとのインメモリデータ
// ==========================================
type Illustration struct {
	ID          int64
	Fingerprint uint64
}

// イラストレーターごとの木構造と画像リストをセットで管理
type IllustratorData struct {
	Tree          *BKTree
	Illustrations []Illustration
}

type SimilaritiesResponse struct {
	SimilarIDs []int64 `json:"similar_ids"`
}

type InsertFingerprintRequest struct {
	ID            int64 `json:"id"`
	IllustratorID int64 `json:"illustrator_id"`
	Fingerprint   int64 `json:"fingerprint"`
}

var db *sql.DB

// イラストレーターIDをキーにしたインメモリデータ
var illustratorDataMap map[int64]*IllustratorData

// BK-Tree（とそれを管理するマップ）へのアクセス権限（鍵）
var dataMu sync.RWMutex


func main() {
	// MySQLへの接続を確立
	initDB()
	defer db.Close()

	// 起動時に一度だけDBから全データを読み込んでBK-Treeを構築
	buildAllTrees()

	// ルーティング
	http.HandleFunc("/similarities", handleSimilarities)
	http.HandleFunc("/rebuild", handleRebuild)
	http.HandleFunc("/insert_fingerprint", handleInsertFingerprint)

	// サーバー起動
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Go APIサーバーをポート %s で起動しています...", port)
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      nil,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  2 * time.Minute,
	}
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("サーバーの起動に失敗しました: %v", err)
	}
}

// ==========================================
// MySQLへの接続を確立
// ==========================================
func initDB() {
	var err error
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s",
		os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"),
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_NAME"),
	)

	db, err = sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("MySQL接続初期化に失敗しました: %v", err)
	}

	// docker-compose起動時のDB起動待ちのためのリトライ処理
	for i := 0; i < 15; i++ {
		err = db.Ping()
		if err == nil {
			log.Println("MySQLへの接続に成功しました")
			return
		}
		log.Printf("DBの起動を待機しています... %v", err)
		time.Sleep(2 * time.Second)
	}
	_ = db.Close()
	log.Fatalf("MySQLへの接続に失敗しました: %v", err)
}

// ==========================================
// 全イラストレーターのBK-Treeをメモリ上に構築
// ==========================================
func buildAllTrees() {
	rows, err := db.Query("SELECT id, illustrator_id, fingerprint FROM illustrations WHERE fingerprint IS NOT NULL")
	if err != nil {
		log.Printf("BK-Tree構築クエリエラー: %v", err)
		return
	}
	defer rows.Close()

	newMap := make(map[int64]*IllustratorData)
	count := 0

	for rows.Next() {
		// 列ごとにデータを取得
		var id, illustratorID int64
		var fp int64
		if err := rows.Scan(&id, &illustratorID, &fp); err != nil {
			log.Printf("BK-Tree構築スキャンエラー: %v (id=%d, illustrator_id=%d)", err, id, illustratorID)
			return
		}

		// イラストレーターごとにBK-Treeのひな型を作成
		if _, exists := newMap[illustratorID]; !exists {
			newMap[illustratorID] = &IllustratorData{
				Tree: &BKTree{},
			}
		}

		// BK-Treeに実データを挿入
		ufp := uint64(fp)
		newMap[illustratorID].Tree.Insert(id, ufp)
		newMap[illustratorID].Illustrations = append(newMap[illustratorID].Illustrations, Illustration{ID: id, Fingerprint: ufp})

		count++
	}

	// ループが正常に終了したかを確認
	if err := rows.Err(); err != nil {
		log.Printf("BK-Tree構築の行走査エラー: %v", err)
		return
	}

	// BK-Treeを更新（更新中は他からのBK-Treeへのアクセスをロック）
	dataMu.Lock()
	illustratorDataMap = newMap
	dataMu.Unlock()

	log.Printf("BK-Treeの構築が完了しました（全%d件）", count)
}

// ==========================================
// BK-Treeをもとに類似画像の検索
// ==========================================
func handleSimilarities(w http.ResponseWriter, r *http.Request) {
	illustratorIDStr := r.URL.Query().Get("illustrator_id")
	thresholdStr := r.URL.Query().Get("threshold")

	illustratorID, err := strconv.ParseInt(illustratorIDStr, 10, 64)
	if err != nil {
		http.Error(w, "illustrator_idが不正です", http.StatusBadRequest)
		return
	}

	threshold, err := strconv.Atoi(thresholdStr)
	if err != nil {
		threshold = 5 // デフォルトのしきい値
	}

	// 指定されたイラストレーターのBK-Treeを参照
	dataMu.RLock()
	data, exists := illustratorDataMap[illustratorID]
	dataMu.RUnlock()

	result := []int64{}
	if exists && data.Tree.Root != nil {
		similarIDsMap := make(map[int64]bool)

		for _, img := range data.Illustrations {
			// 類似判定：対象の画像（img）とBK-Treeを比較
			similar := data.Tree.Search(img.Fingerprint, threshold)

			if len(similar) > 1 {
				for _, sid := range similar {
					similarIDsMap[sid] = true  // マップに追加（重複分は上書きされる）
				}
			}
		}

		// Rubyで処理できる配列に変換
		for id := range similarIDsMap {
			result = append(result, id)
		}
	}

	// Rubyにレスポンス
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(SimilaritiesResponse{SimilarIDs: result})
}

// ====================================================================
// 単一画像の「類似判定用データ」をBK-Treeに追加（全件ロード回避のため）
// ====================================================================
func handleInsertFingerprint(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POSTメソッドのみ受け付けます", http.StatusMethodNotAllowed)
		return
	}

	var req InsertFingerprintRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "リクエスト内容の解析に失敗しました", http.StatusBadRequest)
		return
	}

	if req.ID == 0 || req.IllustratorID == 0 {
		http.Error(w, "id または illustrator_id が不正です", http.StatusBadRequest)
		return
	}

	ufp := uint64(req.Fingerprint)

	// BK-Treeを更新するため他からのアクセスをロック
	dataMu.Lock()
	defer dataMu.Unlock()

	// 対象イラストレーターのBK-Treeがもしまだなければひな形を構築（初回アップロード時など）
	if illustratorDataMap == nil {
		illustratorDataMap = make(map[int64]*IllustratorData)
	}
	data, exists := illustratorDataMap[req.IllustratorID]
	if !exists {
		data = &IllustratorData{
			Tree: &BKTree{},
		}
		illustratorDataMap[req.IllustratorID] = data
	}

	// BK-Treeに実データを追加
	data.Tree.Insert(req.ID, ufp)
	data.Illustrations = append(data.Illustrations, Illustration{ID: req.ID, Fingerprint: ufp})

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "inserted"})
}

// ==========================================
// BK-Treeの再構築
// ==========================================
func handleRebuild(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POSTメソッドのみ受け付けます", http.StatusMethodNotAllowed)
		return
	}

	log.Println("BK-Treeの再構築リクエストを受信しました")

	buildAllTrees()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "再構築が完了しました"})
}
