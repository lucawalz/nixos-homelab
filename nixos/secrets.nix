let
  # SSH public keys
  master = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPM3UxLBpKnPY53bDG2qe4QoQYxcTB8QUfdgg6MoAasx master@homelab";
  worker1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDYjAKKBMs+SgUQHRkmLKQLT1z/pFc2qm54pkIeO7G/K worker-1@homelab";
  lucawalz = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHoKFFTFmJR1CSAq55TwXHbUPTxSK847qZL0W6r/ZUV9 luca@macbook";
  
  allNodes = [ master worker1 ];
  admins = [ lucawalz ];
in {
  # K3s cluster join token - FIXED PATH
  "secrets/k3s-token.age".publicKeys = allNodes ++ admins;
}
