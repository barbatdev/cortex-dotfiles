# Enter a fresh timestamped Herdr session. Usage: hnew [path]
function hnew --description 'Enter a fresh Herdr session'
    hrole "new-"(date +%H%M%S)-(random) $argv
end
