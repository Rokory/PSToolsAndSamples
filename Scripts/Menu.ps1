# Menu items are defined as array of hash tables
# in order to not needing long Write-Host sequences
# and to provide consistent formatting.
# Arrays are defined using @()
# Hashtables are defined using @{}

$menuitems = @(
    @{text = 'Menu item 1'; key = 'a'}
    @{text = 'Menu item 2'; key = 'b'}
    @{text = 'Menu item 3'; key = 'c'}
    @{text = 'Quit'; key= 'q'}
)

# This is an endless loop. The program is exited at some point
# inside the loop. (Sorry for that, Nikolaus Wirth!)
do {
    # Menu items are displayed consistently using a foreach loop
    foreach($menuitem in $menuitems) {
        Write-Host `
            -Object "$($menuitem.key): $($menuitem.text)" `
            -ForegroundColor 'white' `
            -BackgroundColor 'blue'
    }

    # Read input from user
    $result = Read-Host -Prompt 'Please select'

    # Process the user input
    # In a real controller script, replace Write-Host with custom actions
    switch ($result) {
        'a' { Write-Host 'Do a' }
        'b' { Write-Host 'Do b' }
        'c' { Write-Host 'Do c' }
        # If user presses q, exit the script
        'q' { exit }
        # The default branch is executed, if the user input is something
        # other.
        Default { Write-Host 'Wrong input' -BackgroundColor 'red' -ForegroundColor 'white'}
    }
# Display the menu as an endless loop (unti q is pressed).
} while ($true)
