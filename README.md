# ChromaCam

PB（#F40671） / BB（#0069FC） / YB（#FDB200）の背景を自動判別して透過し、カメラ映像に重ねて撮影する Flutter アプリです。

非公式の個人制作です。

バンダイナムコエンターテインメントおよび Cygames とは無関係です。ゲーム画像は配布しません。

自分で撮ったスクリーンショットだけを端末内で処理します。

## できること

- 画像の複数選択・あとからの追加
- 背景色の自動判別とクロマキー透過
- 透過素材をカメラに重ねて撮影
- 複数レイヤーの移動・拡大縮小・不透明度・並べ替え
- 縦 3:4 / 横 4:3 のプレビューと保存
- カメラ倍率
- 配置リセット
- アルバム「ChromaCam」へ JPEG 保存

## 使い方

1. フォトスタジオなどで PB / BB / YB 背景の画像を用意する
2. アプリで「ファイルを選ぶ」
3. 「カメラで撮る」
4. 位置と大きさなどを合わせて撮影する

## 対応

| プラットフォーム | 状態 |
|---|---|
| Android | APK を Release で配布。実機確認済み。 |
| iOS | ソース同梱。Xcode で署名すれば実機に入れられます。TestFlight / App Store では未配布 |

## Android

```bash
flutter pub get
flutter run
```

APK（端末向けは arm64 だけでよい）:

```bash
flutter build apk --release --split-per-abi
```

`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` を使います。

野良 APK です。インストール時に「提供元不明のアプリ」の許可が必要です。

権限はカメラと写真保存です。初回起動時にシステムダイアログが出ます。

## iOS

macOS と Xcode が必要です。Windows / Linux では iOS ビルドはできません。

```bash
flutter pub get
flutter run
```

初回は `ios/Runner.xcworkspace` を Xcode で開き、
Runner → Signing & Capabilities で Team を選びます。
有料の Apple Developer Program が無くても、自分の iPhone へのデバッグインストールはできます。

他人が GitHub のソースから入れる場合も、各自の Apple ID で署名してください。署名済み ipa の配布はしません。

`ios/Runner/Info.plist` に用途説明が必要です。

- `NSCameraUsageDescription` … 合成撮影
- `NSPhotoLibraryAddUsageDescription` … アルバム保存
- `NSPhotoLibraryUsageDescription` … 保存先へのアクセス
- `CFBundleDisplayName` … `ChromaCam`

Flutter 3.47 では CocoaPods の `Podfile` が最初から無いことがあります。Swift Package Manager でビルドされます。`pod install` は必須ではありません。

## Web

https://y-li27.github.io/chroma_cam/
にスマートフォンやタブレットからアクセス。
PC（Windows/macOS/Linux）では動きません。

### Web Android
ほとんどネイティブのように動きますが、動作がキビキビします。

### Web iOS
全体的に動作がもっさりしてます。
サポート対象外です。

## 注意

- ゲームの素材・公式アセットはリポジトリに含めていません。 
- `android/local.properties`、署名鍵、`key.properties`、`*.jks` はコミットしません。
- `ios/Pods/` と `ios/Flutter/ephemeral/` はコミットしない

## ライセンス

ソースコードは作者の判断で公開しています。
ゲーム内のキャラクター・画像の権利は各権利者に帰属します。
