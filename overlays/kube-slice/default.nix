self: super: {
  kubectl-slice = super.buildGoModule rec {
    pname = "kubectl-slice";
    version = "1.4.2";

    src = super.fetchFromGitHub {
      owner = "patrickdappollonio";
      repo = "kubectl-slice";
      tag = "v${version}";
      hash = "sha256-C9YxMP9MCKJXh3wQ1JoilpzI3nIH3LnsTeVPMzri5h8=";
    };

    subPackages = [ "." ];

    ldflags = [
      "-s"
      "-w"
      "-X main.version=v${version}"
      "-extldflags \"-static\""
    ];

    vendorHash = "sha256-Lly8gGLkpBAT+h1TJNkt39b5CCrn7xuVqrOjl7RWX7w=";

    preCheck = ''
      unset subPackages
    '';

    meta = with super.lib; {
      description = "Nix package for kubectl-slice";
      mainProgram = "kubectl-slice";
      homepage = "https://github.com/packtrickdappollonio/kubectl-slice";
      license = licenses.asl20;
    };
  };
}
