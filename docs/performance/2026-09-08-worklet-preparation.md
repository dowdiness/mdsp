# AudioWorklet上の準備処理と出力欠落の測定

## 判断

この条件では、演奏中の準備・適用による出力欠落は確認できなかった。
準備処理をWorkerへ移すことを、今回の性能測定だけを根拠に必須とはしない。
準備・適用・再生制御を分離するAPI設計は維持し、転送形式や別実装を増やす前に、
実機・初回編集・負荷のある環境で同じ測定を行う。

これはリアルタイム安全性の保証ではない。対象はLinux/WSL2上の
HeadlessChrome 145.0.7632.6、48 kHz、128 samples、interactive latencyである。
物理スピーカー出力の録音や人による聴取は行っていない。

## 対象と測定方法

基点は `d7a69754f91e04bc98afa190bdc9835212267272`。release wasm-gcを専用worktreeで
ビルドした。WASMのSHA-256は[測定データ](2026-09-08-worklet-preparation.json)に記録した。
本体の `web/scheduler-processor.js` に計測用subclassを追加して読み込み、
本体のrender、共有PlaybackController、WASMのprepare/applyをそのまま呼び出す。
製品コードと公開APIは変更していない。

12セクション・240 cycles・2,842文字の合成曲を使う。旋律の異なる2種類を交互に送り、
同一文字列だけの反復に偏らないようにする。各条件は新しいAudioContextで開始し、
初回の曲を適用して2秒待つ。250ms間隔で24回の操作を行い、最後に1.5秒待つ。
準備は曲全体を対象とするが、各測定中に再生するのは冒頭約19 cyclesであり、
全240 cyclesの演奏や終盤の負荷を検証した測定ではない。

以下の4条件を3回測定し、回ごとに順序を巡回させた。1回の計測窓は約7.5秒。

- baseline: 通常再生のみ。
- prepare-only: 解析・snapshot生成まで行い、tokenを破棄する。
- apply-score: 準備結果を継続適用する。各回24件の適用完了通知を確認する。
- positive-control: 同じaudio ownerで100msの意図的な停止を24回発生させる。

ブラウザの実験フラグ `AudioContextPlayoutStats` を明示的に有効にした。
デフォルト設定ではこのブラウザに出力統計がなかった。出力欠落の検出には
`playoutStats` の累積値の差を使う。統計は即時更新ではないため待機時間を含める。
準備・ハンドラー・renderの時間は、このAudioWorkletで利用できる `Date.now()` による
1ms単位の観測であり、サブミリ秒の精度はない。計測値は事前確保した配列に記録する。
準備時間は入力文字転送を除き、ハンドラー時間は文字転送とapply/discardを含む。

## 結果

| 条件 | 出力欠落イベント（各回） | 欠落時間ms（各回） | 準備p95 ms（各回） | ハンドラー最大ms（各回） |
|---|---|---|---|---|
| 通常再生 | 0 / 0 / 0 | 0 / 0 / 0 | — | — |
| 準備のみ | 0 / 0 / 0 | 0 / 0 / 0 | 1 / 1 / 1 | 1 / 1 / 1 |
| 準備して継続適用 | 0 / 0 / 0 | 0 / 0 / 0 | 1 / 1 / 1 | 1 / 1 / 1 |
| 意図的な100ms停止 | 29 / 32 / 33 | 337.125 / 372 / 383.625 | — | 100 / 100 / 100 |

準備は両条件それぞれ72回、合計144回。記録された準備最大値も全回1msだった。
すべての条件で個々のrenderの最大値は1msだった。1msという値を正確な上限保証には使わない。

既知の大きな停止は全回検出できたため、「欠落0」は統計が常に0のままだった結果ではない。
ただし、この校正は短い停止の検出感度やすべての出力装置の挙動まで保証しない。
[集計結果](2026-09-08-worklet-preparation-summary.json)は、欠測値を0に置換せず、
統計の単調増加、比較条件の揃い、陽性対照の検出を検証して生成した。

コールバック間隔は通常時でも約24msのまとまりがあり、128 samplesの2.667msと
単純に比較して締切違反を数えることはできない。生データの `callback_gap` 内の
`over_block_budget` は単なる数値比較であり、音切れ・締切違反の件数ではない。
出力欠落の判断にはその数を使用していない。

ページ内WASMの先行測定では準備p95が3.3msだったが、今回のAudioWorklet測定では再現しなかった。
実行環境、初期化、ウォームアップ、計時精度が異なるため、これを高速化した証拠とは扱わない。
また、2.667msは1ブロックの時間であり、それを超えた処理が必ず出力欠落になるわけでもない。

## 次の実装判断

現時点ではWorker移行の実装を始めない。次の測定では、同じハーネスを実出力装置のある
ブラウザで動かし、初回準備を含む編集、長時間再生、CPU競合を個別に比較する。
準備と同期して欠落が増えるなら、転送可能な準備結果か期限付きイベント列を小さく試し、
転送・構築・適用を含む総コストと出力欠落を同じ条件で再比較する。
関数を含む現行snapshotをそのままWorker間転送する設計にはしない。

## 再実行と検証

```bash
npm ci
NEW_MOON_MOD=0 moon build browser --target wasm-gc --release
WORKLET_STATS_EXPERIMENTAL=1 node scripts/measure-worklet-preparation.cjs /tmp/worklet.json 3
node scripts/worklet-measurement/analyze.cjs /tmp/worklet.json
node --test scripts/worklet-measurement/analyze.test.cjs
```

GUI環境では `WORKLET_HEADED=1` を追加できる。実験フラグなしでも動作するが、
統計がない場合は校正不成立となり、出力欠落がないとは結論できない。
ブラウザが新しい `playbackStats` を公開する場合、集計は秒からmsへ単位を変換する。

検証済み: release build、ハーネスの構文チェック、実AudioWorkletでの12条件実行、
集計器の欠測・単位変換・停止未検出・統計停止/リセット検証。本体コードは変更しておらず、
この測定のために製品の全テストやCLAPを再実行してはいない。

## 根拠となる仕様

- [Web Audio API: AudioPlaybackStats](https://webaudio.github.io/web-audio-api/#audioplaybackstats): 出力欠落と累積統計、更新頻度の定義。
- [WICG Playout Statistics](https://wicg.github.io/audio-context-playout-stats/): 今回のChromiumが公開する旧APIのms単位とfallbackの意味。

出力統計にはAudioWorklet以外の原因による欠落も含まれるため、通常再生との比較と
既知の停止による校正を併用する。
