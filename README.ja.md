# Crayon

[EN](README.md) · [KR](README.ko.md) · [JP](README.ja.md) · [CN](README.zh-CN.md)

SwiftUI でクレヨンの塗り、ブラシ線、ざらついた輪郭、ボイリングアニメーションを描く Swift Package です。
外部画像なしでクレヨンの質感を生成でき、独自のブラシ先端とグレインも使用できます。

![淡い斜めの塗り重ね、紙の隙間、ざらついた輪郭のクレヨン塗り](Documentation/Images/crayon.png)

- **対応環境:** iOS 17+ · macOS 14+ · Swift tools 5.9+
- **製品 / import:** `Crayon`
- SwiftUI ベースで、外部パッケージへの依存はありません。

## クイックスタート

Xcode の **Add Package Dependencies → Add Local** でこのリポジトリを選び、
アプリのターゲットに `Crayon` 製品を追加してください。

```swift
import SwiftUI
import Crayon

struct Drawing: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .brushFill(
                color: Color(red: 1, green: 0.84, blue: 0.25),
                textureStrength: 0.9,
                fillStyle: .crayon(grainSize: 1, seed: 7)
            )
            .frame(width: 280, height: 180)
            .padding(16)
    }
}
```

別の Swift Package からローカル依存として追加することもできます。

```swift
// Package.swift の dependencies
.package(path: "../crayon")

// 利用するターゲットの dependencies
.product(name: "Crayon", package: "crayon")
```

## 描けるもの

| API | 用途 |
| --- | --- |
| `Shape.brushFill(..., fillStyle: .grain)` | 用意したブラシのグレインで塗りつぶす既定のスタイル |
| `Shape.brushFill(..., fillStyle: .crayon(...))` | ワックスの塗り重ね、紙の隙間、ざらついた輪郭を持つクレヨン塗り |
| `Shape.brushStroke` / `Path.brushStroke` | パスに沿ってブラシ先端を重ねて線を描く |
| `Color.texturing` | 単色図形の輪郭をざらつかせる |
| `View.boiling` | 手描きのようにわずかに揺れるアニメーション |

![同じ brushFill API の grain と crayon、および brushStroke の比較](Documentation/Images/drawing-styles.png)

プレビューは、このリポジトリの公開 API と既定の `.monoline` ブラシで描画しています。
独自のブラシを渡すと、`.grain` の塗りとブラシ線の見た目が変わります。

## クレヨン塗り

**同じ `brushFill` API** の `fillStyle` で選択します。
クレヨン専用のモディファイアやテクスチャ画像は不要です。

固定された紙の凹凸に、3 回のワックスの塗りが重なる過程を簡略化したモデルです。
圧力が届かない溝には紙が透け、塗り重ねた部分には淡い斜めの濃淡が残ります。
輪郭には塗り終わりの位置や細かな粒子のばらつきを反映し、別の輪郭線は描きません。

![クレヨンの質感の強さ 0、0.5、1 の比較](Documentation/Images/crayon-strength.png)

| 設定 | 既定値 | 説明 |
| --- | --- | --- |
| `color` | `.primary` | 塗りの色。色の不透明度を維持します。 |
| `textureStrength` | `0.8` | `0...1`。0 は単色、1 は紙の隙間とざらついた輪郭が最もよく現れます。 |
| `.crayon(grainSize:)` | `1` | `0.5...4`。紙の粒子と塗り跡の空間的な大きさを調整します。 |
| `.crayon(seed:)` | `0` | 同じサイズと設定で同じパターンを再現する値です。 |

`grainScale` と `BrushTip` は `.grain` スタイル用です。
`fillStyle` は質感を選択し、別の `style: FillStyle` は SwiftUI の even-odd 塗りつぶし規則とアンチエイリアスを設定します。

レイアウトのサイズは変わりませんが、クレヨンの粒子は元の輪郭の外に少しはみ出します。
描画用の余白は `ceil(5 × grainSize × textureStrength) + 1` pt です。
親ビューの `.clipped()` によって粒子が切れることがあります。強さが 0 のときは追加のはみ出しはありません。

## ブラシの塗りと線

```swift
RoundedRectangle(cornerRadius: 24)
    .brushFill(.monoline, color: .orange, textureStrength: 0.8)
    .overlay {
        RoundedRectangle(cornerRadius: 24)
            .brushStroke(.monoline, color: .brown, width: 3)
    }
    .frame(width: 220, height: 140)
```

`brushStroke` では `width`（pt）、`spacing`、`flow`、`grainScale` を調整できます。
線は図形の境界を中心に描かれるため、外側の線が見えるように余白を確保してください。
`Path` にも同じ API を使用できます。

### カスタムブラシ

```swift
// 画像ファイルの URL から一度読み込み、再利用します。
let tip = try BrushTip(shapeURL: shapeURL, grainURL: grainURL)

// SwiftUI ビュー内で使用
Circle()
    .brushFill(tip, color: .blue, grainScale: 240)
    .frame(width: 160, height: 160)
```

`BrushTip.monoline` は外部リソース不要の標準ブラシです。
画像ローダーは白い背景の黒い描画をアルファマスクに変換し、先端画像の透明な余白を切り取ります。
入力は一辺最大 4096 px です。読み込めない画像では `BrushTip.LoadError.invalidImage` がスローされます。
Procreate のブラシファイルを直接解析する機能はありません。

## 輪郭のテクスチャ

```swift
Color.blue.texturing(
    in: .roundedRectangle(cornerRadius: 12),
    x: 0.5, y: 0.5, radius: 4,
    pattern: TexturingPattern(
        grainSize: 0.6, coarseSize: 3, roughness: 0.4, seed: 42
    )
)
.frame(width: 220, height: 140)
```

単色図形用の効果です。`TexturingShape` は長方形、角丸長方形、カプセル、円に対応し、
通常の `Shape` としても使用できます。角丸は circular 方式です。
同じ seed と座標からは同じパターンが生成されます。

## ボイリングアニメーション

```swift
Circle()
    .brushStroke(.monoline, color: .blue, width: 4)
    .boiling(amount: 1.2, framesPerSecond: 6)
    .frame(width: 120, height: 120)
```

3 種類の固定した変形を順番に切り替えます。背景や文字まで揺れないよう、装飾用のビューに適用してください。
「視差効果を減らす」が有効な場合、シーンが非アクティブな場合、ビューが画面から消えた場合は停止します。
README の画像は静止画のため、動きはサンプルアプリで確認してください。

## サンプルアプリの実行

[CrayonSample.xcodeproj](Examples/CrayonSample/CrayonSample.xcodeproj) を Xcode で開き、
`CrayonSample` スキームと iOS Simulator または My Mac を選んで実行してください。
リポジトリ内のパッケージをローカル参照するため、別途インストールする必要はありません。

色、質感の強さ、クレヨンの塗り跡の大きさを変更し、クレヨン塗り、標準グレイン、ブラシ線、
輪郭テクスチャを比較できます。ボイリングのオン・オフを切り替えるトグルもあります。

同じローカルパッケージを別のプロジェクトで開いていると、Xcode に
`already opened from another project or workspace` と表示されることがあります。
そのプロジェクトのウインドウを閉じてから、サンプルを開き直してください。

```sh
xcodebuild -project Examples/CrayonSample/CrayonSample.xcodeproj \
  -scheme CrayonSample -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

## 開発と検証

```text
Sources/Crayon/
  BrushStroke/        # 線・塗りの公開 API、サンプリング、クレヨン描画、ラスターキャッシュ
  Texturing/          # 輪郭テクスチャの API とレンダラー
  Boiling/            # ボイリングの View modifier
  Shaders/            # EdgeTexture.metal, LineBoil.metal
Examples/CrayonSample/ # iOS / macOS サンプルアプリ
Tests/CrayonTests/     # 幾何・画像読み込み・公開 API・描画の回帰テスト
Tools/PreviewGenerator/ # README 画像生成ツール
Documentation/Images/ # 生成されたプレビュー PNG
```

Metal をコンパイルできる Xcode / Metal Toolchain が必要です。
シェーダーはパッケージバンドルの `default.metallib` にコンパイルされ、`ShaderLibrary.bundle(.module)` で読み込まれます。
アプリの既定のシェーダーライブラリや `Bundle.main` には依存しません。

```sh
swift build
swift test
```

SwiftPM が Metal Toolchain を見つけられない環境では、次のコマンドで Swift コードの回帰テストを実行できます。
native ビルドシステムは Metal ソースをコピーするだけなので、上記の Xcode サンプルビルドでシェーダーのコンパイルも確認してください。

```sh
swift test --build-system native
```

直近の実装検証: **回帰テスト 11 件成功**、**iOS Simulator 向けサンプルアプリのビルド成功**。
効果やアニメーションはサンプルアプリで確認してください。ルートパッケージはライブラリのため、`swift run` の実行対象はありません。

### プレビュー画像の再生成

macOS でリポジトリのルートから実行します。実際の `Crayon` 公開 API を SwiftUI `ImageRenderer` で描画し、
2 倍解像度の PNG に保存します。固定 seed とライトモードを使用します。

```sh
swift run --package-path Tools/PreviewGenerator --build-system native \
  PreviewGenerator Documentation/Images
```

このツールはクレヨン塗り、グレイン塗り、ブラシ線の静止画を生成します。
Metal ベースの輪郭効果とボイリングはサンプルアプリで確認してください。
