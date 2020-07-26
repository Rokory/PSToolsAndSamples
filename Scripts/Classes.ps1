# Declare an enumeration
enum DeviceType {
    Undefined = 0
    Compute = 1
    Storage = 2
    Networking = 4
    Communications = 8
    Power = 16
    Rack = 32
}

# Declare a class

class Asset {
    # Properties are declared like variables
    [string]$Brand
    [string]$Model

    # Constructors are delared using the class name
    Asset() {
        $this.Brand = 'Undefined'
    }

    # Multiple constructors with different parameter sets can be declared
    Asset([string] $brand, [string] $model) {
        $this.Brand = $brand
        $this.Model = $model
    }
    # Methods are declared like functions without the function keyword
    [string] ToString() {
        return ("{0}|{1}" -f $this.Brand, $this.Model)
    }
}

# Declare a class, derived from another class
class Device : Asset {
    # Hidden attributes are still accessible, but not shown e. g. by Get-Member
    hidden [DeviceType] $devtype = [DeviceType]::Undefined

    [string]$VendorSku

    # Calling the constructor of the base class
    Device() : base () {
    }

    Device(
        [string] $brand, 
        [string] $model, 
        [string] $vendorSku
    ) : base ($brand, $model) {
        $this.VendorSku = $vendorSku
    }

    # Child classes can override methods from the base class
    [string] ToString(){
        return ("{0}|{1}" -f (
            # To call base class methods from overridden implementations, 
            # cast to the base class ([baseclass]$this) on invocation.
            [Asset]$this).ToString(), $this.VendorSku)
    }

    [DeviceType] GetDeviceType() {
        return $this.devtype
    }
}

# Create an instance using constructor
$device = [Device]::new()
$surface = [Device]::new()


$surface.Brand = 'Microsoft'
$surface.Model = 'Surface Pro 4'
$surface.VendorSku = '5072641000'

$go = [Device]::new('Microsoft', 'Surface Go', 'MCZ-00002')

# Create an instance using New-Object
$thinkpad = New-Object `
    -TypeName Device `
    -ArgumentList 'Lenovo', 'ThinkPad T490', 'S60D4L5'

$device.ToString()
$surface.ToString()
$thinkpad.ToString()
$go.ToString()

# Complex types in class properties

class Rack : Asset {
    [int] hidden $Slots = 8

    # Static attributes exist on the class instead of the instance
    static [Rack[]] $InstalledRacks = @()

    [string]$VendorSku
    [string]$AssetId
    [Device[]]$Devices = [Device[]]::new($this.Slots)

    Rack (
        [string] $brand = $null, 
        [string] $model = $null, 
        [int] $capacity = 8
    ) : base ($brand, $model) {
        ## argument validation here

        $this.Slots = $capacity

        ## add rack to installed racks
        [Rack]::InstalledRacks += $this

        ## reset rack size to new capacity
        $this.Devices = [Device[]]::new($this.Slots)
    }

    # Methods, that do not return a value, are declared with [void]
    [void] AddDevice([Device]$dev, [int]$slot){
        ## Add argument validation logic here
        $this.Devices[$slot] = $dev
    }

    [void] RemoveDevice([int]$slot){
        ## Add argument validation logic here
        $this.Devices[$slot] = $null
    }

    [int[]] GetAvailableSlots(){
        [int]$i = 0
        return @($this.Devices.foreach{ if($_ -eq $null){$i}; $i++})
    }

    # declare static methods
    # static mathods are called on the class instead of an object
    static [void] PowerOffRacks(){
        foreach ($rack in [Rack]::InstalledRacks) {
            Write-Warning ("Turning off rack: $($rack.AssetId)")
        }
    }
}

$rack = [Rack]::new('', '', 16)
$rack.AssetId = New-Guid
$rack.AddDevice($surface, 2)
$rack.AddDevice($thinkpad, 3)
$rack
$rack.GetAvailableSlots()
[Rack]::PowerOffRacks()