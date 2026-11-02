$Destination = Invoke-ImmyCommand {
    switch($Using:Location) {
        "AllUsersDesktop" {
            $Destination = "$($env:Public)\Desktop"
        }
        "WindowsFolder" {
            $Destination = "$($env:SystemRoot)"
        }
        "OtherLocation" {
            $Destination = "$($Using:OtherLocation)"
        }
    }
    return $Destination
}

$File | FileShould-Be -InPath $Destination