{
	description = "LiveSplit One — druid frontend";

	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		livesplit-one-druid = {
			url = "github:AlexKnauth/livesplit-one-druid";
			flake = false;
		};
	};

	outputs = { self, nixpkgs, livesplit-one-druid, ... }: let
	systems = [ "x86_64-linux" "aarch64-linux" ];
	forAllSystems = nixpkgs.lib.genAttrs systems;
	pkgsFor = system: import nixpkgs { inherit system; };

	nativeBuildInputs = pkgs: with pkgs; [
		pkg-config
		rustPlatform.bindgenHook
		wrapGAppsHook3
	];

	buildInputs = pkgs: with pkgs; [
		glib
		cairo
		gtk3
		gsettings-desktop-schemas
	];
	in {
		packages = forAllSystems (system: let
		pkgs = pkgsFor system;
		in {
			default = pkgs.rustPlatform.buildRustPackage {
				pname = "livesplit-one";
				version = "0.7.2";

				src = livesplit-one-druid;

				cargoLock = {
					lockFile = "${livesplit-one-druid}/Cargo.lock";
					outputHashes = {
						"druid-0.8.3" = "sha256-AnODiTQSC/tFIVQr4SrQg9Gu3NEE2Y5VG3lEVpVgqdo=";
						"livesplit-core-0.13.0" = "sha256-fe8Xndkmh8W2YDdPwwVf+iRQbiujBNofuYH3Us1BC7g=";
					};
				};

				nativeBuildInputs = nativeBuildInputs pkgs;
				buildInputs = buildInputs pkgs;
			};
		});

		devShells = forAllSystems (system: let
		pkgs = pkgsFor system;
		in {
			default = pkgs.mkShell {
				nativeBuildInputs = nativeBuildInputs pkgs;
				buildInputs = (buildInputs pkgs) ++ (with pkgs; [
					rustc
					cargo
					rustfmt
					clippy
					rust-analyzer
				]);

				RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
			};
		});

		nixosModules.default = { lib, config, pkgs, ... }: {
			options.programs.livesplit-one = {
				enable = lib.mkEnableOption "enable LiveSplit";
				setcap = lib.mkOption {
					type = lib.types.bool;
					default = true;
				};
			};

			config = let
			pkg = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
			cfg = config.programs.livesplit-one;
			in lib.mkIf cfg.enable {
				environment.systemPackages = [ pkg ];
				security.wrappers.LiveSplitOne = lib.mkIf cfg.setcap {
					source = "${pkg}/bin/LiveSplitOne";
					capabilities = "cap_sys_ptrace+eip";
					owner = "root";
					group = "root";
				};
			};
		};
	};
}
