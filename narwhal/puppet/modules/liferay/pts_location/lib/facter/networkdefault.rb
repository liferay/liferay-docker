require 'facter'
Facter.add(:networkdefault) do
  setcode do
    # Load all default facts
    Facter.loadfacts()

    # Retrieve our custom fact, ifdefault
    ifdefault=Facter.value(:ifdefault)

    # Now compose the name of the fact containing the ip address of the
    # interface returned by ifdefault, and return it
    Facter["network_#{ifdefault}"].value()
  end
end
