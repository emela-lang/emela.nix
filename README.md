# emela-lang/nix

[Emela](https://github.com/emela-lang/emela) 用の Nix flake / overlay。

- **既定**: GitHub Releases の**プリビルドバイナリ**を取得して `emela` として提供（Rust ツールチェイン不要）。
- **フラグ**: `fromSource` を立てると、**main HEAD をソースからビルド**（`rust-toolchain.toml` にピン留めした Rust 環境を使用）。

対応プラットフォーム:

| system | プリビルドバイナリ | ソースビルド |
| --- | --- | --- |
| `aarch64-darwin` | ✅ | ✅ |
| `x86_64-linux` | ✅ | ✅ |
| `aarch64-linux` / `x86_64-darwin` | ❌（未公開） | ✅ |

## クイックスタート

```sh
# プリビルドバイナリを実行
nix run github:emela-lang/emela.nix

# プロファイルに導入
nix profile install github:emela-lang/emela.nix#emela

# main HEAD をソースからビルドして実行
nix run github:emela-lang/emela.nix#emela-source
```

## overlay として使う

`overlays.default` は `pkgs.emela`（プリビルドバイナリ）と `pkgs.emela-source`（ソースビルド）を追加する。

```nix
{
  inputs.emela.url = "github:emela-lang/emela.nix";

  outputs = { nixpkgs, emela, ... }:
    let
      pkgs = import nixpkgs {
        system = "aarch64-darwin";
        overlays = [ emela.overlays.default ];
      };
    in {
      # pkgs.emela        … プリビルドバイナリ
      # pkgs.emela-source … main HEAD のソースビルド
      packages.aarch64-darwin.default = pkgs.emela;
    };
}
```

NixOS / home-manager では `environment.systemPackages = [ pkgs.emela ];` のように使える。

### フラグ: main HEAD をビルドする

`emela` を丸ごとソースビルドに差し替えたい場合は、以下のいずれか。

```nix
# 1) override フラグで切り替え（最も局所的）
pkgs.emela.override { fromSource = true; }

# 2) fromSource overlay を使う → pkgs.emela がソースビルドになる
overlays = [ emela.overlays.fromSource ];
```

> `overlays.fromSource` を「素の nixpkgs」に適用した場合、ソースビルドは
> nixpkgs 同梱の `rustPlatform` を使う。この flake 経由（`nix build .#emela-source`）
> なら `rust-toolchain.toml`（`stable` + rustfmt + clippy）にピン留めした
> ツールチェインでビルドされる。

## Rust 開発環境

`rust-toolchain.toml` に一致する Rust ツールチェイン（`stable` + rustfmt + clippy）と
`rust-analyzer` を含む devShell。

```sh
nix develop github:emela-lang/emela.nix
# emela のソースツリー（main HEAD のピン留め）が表示される。手元でビルドする例:
#   cargo build -p emela --release
```

## main HEAD の追跡

ソースビルドは `emela-src` input（`flake = false`）が指す commit を使う。最新の
main に追随するには:

```sh
nix flake update emela-src
```

`flake.lock` の `emela-src` が更新され、`emela-source` / `nix run .#emela-source`
がその HEAD をビルドするようになる。

## バージョンの更新と切り替え

ピン留め済みのバージョンとハッシュは [`pkgs/emela/versions.json`](pkgs/emela/versions.json)
に集約されている（`latest` が既定）。Nix は再現性のためにこの表をピン留めして
使うので、更新は「表を書き換える」形で行う。

### 更新

更新スクリプトが最新（または指定）リリースのハッシュを取得して `versions.json` を
書き換える。GitHub API を使わないのでトークン不要・レート制限に当たらない。

```sh
nix run .#update            # 最新の stable リリースに更新
nix run .#update -- 0.8.0   # 特定バージョンを追加してピン
```

差分をコミットすればチームで再現性を保ったまま新バージョンを使える。

### 切り替え / ロールバック

`versions.json` に載っているバージョンは即座に選べる:

```nix
pkgs.emela                              # 既定（latest）
pkgs.emela.override { version = "0.6.0"; }  # 特定バージョンにピン
pkgs.emelaVersions."0.6.0"              # 同上（overlay が公開する版別アトリビュート）
```

```sh
# 常に main HEAD を追いたい場合はソースビルド側を更新
nix flake update emela-src
```

## flake 出力一覧

| 出力 | 説明 |
| --- | --- |
| `packages.<system>.emela` | プリビルドリリースバイナリ（latest、対応 system のみ） |
| `packages.<system>.emela-source` | main HEAD のソースビルド |
| `packages.<system>.default` | バイナリがあれば `emela`、無ければ `emela-source` |
| `apps.<system>.default` | `nix run` 用の `emela` 実行エントリ |
| `apps.<system>.update` | `versions.json` を再ピンする更新スクリプト |
| `devShells.<system>.default` | Rust 開発環境 |
| `overlays.default` | `emela` / `emela-source` / `emelaVersions.<v>` を追加 |
| `overlays.fromSource` | `emela` をソースビルドに差し替え |
