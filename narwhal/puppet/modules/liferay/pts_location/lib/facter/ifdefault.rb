require 'facter'
Facter.add(:ifdefault) do
  setcode do
    # Facter::Util::Resolution::exec("/usr/local/sbin/ifdefault.sh")
    Facter::Util::Resolution::exec("/bin/ip route | /usr/bin/awk '/^default/ {print $5}'")
  end
end
