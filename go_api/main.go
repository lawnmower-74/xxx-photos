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
	return bits.OnesCount64(a ^ b)
}

// ==========================================
// BK-Treeにノードを挿入（O(log N)）
// ==========================================
func (t *BKTree) Insert(id int64, fp uint64) {
	node := &BKNode{
		ID:          id,
		Fingerprint: fp,
		Children:    make(map[int]*BKNode),
	}
	if t.Root == nil {
		t.Root = node
		return
	}
	current := t.Root
	for {
		dist := hammingDistance(current.Fingerprint, fp)
		if child, exists := current.Children[dist]; exists {
			current = child
		} else {
			current.Children[dist] = node
			return
		}
	}
}
// ==================================================================
// BK-Treeから類似ノードを検索（O(log N)）
// しきい値以下のハミング距離を持つノードのみをたどる「枝刈り」を行う
// ==================================================================
func (t *BKTree) Search(fp uint64, threshold int) []int64 {
	if t.Root == nil {
		return nil
	}
	var results []int64
	// スタックを使った深さ優先探索
	stack := []*BKNode{t.Root}
	for len(stack) > 0 {
		current := stack[len(stack)-1]
		stack = stack[:len(stack)-1]

		dist := hammingDistance(current.Fingerprint, fp)
		if dist <= threshold {
			results = append(results, current.ID)
		}
		// 枝刈り: dist ± threshold の範囲にある子ノードだけを探索対象に追加
		// この範囲外の枝は「類似画像が絶対に存在しない」ことが数学的に保証される
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
// 起動時にDBから全件読み込み、以降は /rebuild で更新
var illustratorDataMap map[int64]*IllustratorData
var dataMu sync.RWMutex

func main() {
	initDB()
	defer db.Close()

	// 起動時に一度だけDBから全データを読み込んでBK-Treeを構築
	buildAllTrees()

	http.HandleFunc("/similarities", handleSimilarities)
	http.HandleFunc("/rebuild", handleRebuild)
	http.HandleFunc("/insert_fingerprint", handleInsertFingerprint)

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
// MySQLへの接続を初期化
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
		var id, illustratorID int64
		var fp int64 // DBでは符号付き(BIGINT)として保存されている可能性があるためint64で読み込む
		if err := rows.Scan(&id, &illustratorID, &fp); err != nil {
			log.Printf("BK-Tree構築スキャンエラー: %v (id=%d, illustrator_id=%d)", err, id, illustratorID)
			return
		}
		if _, exists := newMap[illustratorID]; !exists {
			newMap[illustratorID] = &IllustratorData{
				Tree: &BKTree{},
			}
		}
		ufp := uint64(fp)
		newMap[illustratorID].Tree.Insert(id, ufp)
		newMap[illustratorID].Illustrations = append(newMap[illustratorID].Illustrations, Illustration{ID: id, Fingerprint: ufp})
		count++
	}
	if err := rows.Err(); err != nil {
		log.Printf("BK-Tree構築の行走査エラー: %v", err)
		return
	}

	// 書き込みロックを取得してマップを丸ごと入れ替える
	dataMu.Lock()
	illustratorDataMap = newMap
	dataMu.Unlock()

	log.Printf("BK-Treeの構築が完了しました（全%d件）", count)
}

// ==========================================
// 類似画像の検索（/similarities）
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

	// 読み込みロックでマップを参照（複数リクエストの同時読み込みは許可）
	dataMu.RLock()
	data, exists := illustratorDataMap[illustratorID]
	dataMu.RUnlock()

	result := []int64{}
	if exists && data.Tree.Root != nil {
		similarIDsMap := make(map[int64]bool)

		// 各画像に対してBK-Treeで検索（O(N log N)）
		// 総当たりO(N²)とは異なり、枝刈りにより不要な比較をスキップする
		for _, img := range data.Illustrations {
			similar := data.Tree.Search(img.Fingerprint, threshold)
			// 自分自身のみにマッチ（len == 1）の場合は類似画像なしとして除外
			if len(similar) > 1 {
				for _, sid := range similar {
					similarIDsMap[sid] = true
				}
			}
		}

		for id := range similarIDsMap {
			result = append(result, id)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(SimilaritiesResponse{SimilarIDs: result})
}

// ==========================================================
// 単一画像の「類似判定用データ」をBK-Treeに追加
// ==========================================================
func handleInsertFingerprint(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POSTメソッドのみ受け付けます", http.StatusMethodNotAllowed)
		return
	}

	var req InsertFingerprintRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "リクエストボディのパースに失敗しました", http.StatusBadRequest)
		return
	}

	if req.ID == 0 || req.IllustratorID == 0 {
		http.Error(w, "id または illustrator_id が不正です", http.StatusBadRequest)
		return
	}

	ufp := uint64(req.Fingerprint)

	dataMu.Lock()
	defer dataMu.Unlock()

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

	data.Tree.Insert(req.ID, ufp)
	data.Illustrations = append(data.Illustrations, Illustration{ID: req.ID, Fingerprint: ufp})

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "inserted"})
}

// ==========================================
// BK-Treeの再構築（/rebuild）
// 画像の追加・削除後にRailsから呼び出す
// ==========================================
func handleRebuild(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POSTメソッドのみ受け付けます", http.StatusMethodNotAllowed)
		return
	}

	log.Println("BK-Treeの再構築リクエストを受信しました")
	// 同期的に実行してから返す（Railsが再構築完了後の検索結果を受け取れるように）
	buildAllTrees()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "再構築が完了しました"})
}
