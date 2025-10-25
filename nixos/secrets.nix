let
  # SSH public keys
  master = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAU9eaUVbsNWFhRKfzokIBEWY7mfAmb+ISf3kjVKHErx root@master";
  worker1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ9ZMnrZHyY0aE72y6boCYgrUYdX9mMH3r1vWxlSZPbb root@worker-1";
  lucawalz = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHoKFFTFmJR1CSAq55TwXHbUPTxSK847qZL0W6r/ZUV9 luca@macbook";
  
  allNodes = [ master worker1 ];
  admins = [ lucawalz ];
in {
  # K3s cluster join token - FIXED PATH
  "secrets/k3s-token.age".publicKeys = allNodes ++ admins;
}
