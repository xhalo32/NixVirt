{
  sources ? import ./npins,
  system ? builtins.currentSystem,
  pkgs ? import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [ ];
  },
}:
let
  packages = pkgs;

  nixvirtPythonModulePackage =
    packages.runCommand "nixvirtPythonModulePackage" { } ''
      mkdir  -p $out/lib/python3.11/site-packages/
      ln -s ${tool/nixvirt.py} $out/lib/python3.11/site-packages/nixvirt.py
    ''
    // {
      pythonModule = packages.python311;
    };

  pythonInterpreterPackage =
    libvirt:
    packages.python311.withPackages (ps: [
      (ps.libvirt.override { inherit libvirt; })
      ps.lxml
      ps.xmldiff
      nixvirtPythonModulePackage
    ]);

  setShebang =
    name: path: libvirt:
    packages.runCommand name { } ''
      sed -e "1s|.*|\#\!${pythonInterpreterPackage libvirt}/bin/python3|" ${path} > $out
      chmod 755 $out
    '';

  virtdeclareFile = setShebang "virtdeclare" tool/virtdeclare;
  moduleHelperFile = setShebang "nixvirt-module-helper" tool/nixvirt-module-helper;

  mklib = import ./lib.nix;

  modules = import ./modules.nix { inherit packages moduleHelperFile; };

  stuff = { inherit packages; };
in
{
  lib = mklib stuff;

  apps.${system}.virtdeclare = {
    type = "app";
    program = "${virtdeclareFile packages.libvirt}";
  };

  # for debugging
  apps.${system}.nixvirt-module-helper = {
    type = "app";
    program = "${moduleHelperFile packages.libvirt}";
  };

  formatter.${system} = packages.nixpkgs-fmt;

  packages.${system}.default = packages.runCommand "NixVirt" { } ''
    mkdir -p $out/bin
    ln -s ${virtdeclareFile packages.libvirt} $out/bin/virtdeclare
  '';

  homeModules.default = modules.homeModule;

  nixosModules.default = modules.nixosModule;

  checks.${system} = import checks/checks.nix stuff mklib;

  devShells.${system}.default = packages.mkShell {
    buildInputs = with packages; [
      bashInteractive
      just
    ];
  };
}
