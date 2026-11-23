#!/bin/bash
# Creates (or updates) the labels used by iperf3v. Needs an authenticated gh; run from the repository.
set -euo pipefail
label() { gh label create "$1" --color "$2" --description "$3" --force; }
label veille-esnet       0e8a16 "Récapitulatif hebdomadaire des nouveautés ESnet"
label portage            1d76db "Portage de la série vers une nouvelle version ESnet"
label "amont:à-intégrer" d93f0b "Correctif ESnet à reprendre dans notre série"
label "amont:à-suivre"   fbca04 "Élément ESnet à surveiller"
label "amont:ignoré"     cfd3d7 "Élément ESnet sans intérêt pour iperf3v"
label "amont:proposé"    5319e7 "Correctif iperf3v proposé à ESnet"
label bug                d73a4a "Comportement anormal"
label "amélioration"     a2eeef "Demande d'amélioration"
label windows            0052cc "Windows / Cygwin"
label linux              006b75 "Linux"
label syntraf            c5def5 "Trouvé ou utilisé par SYNTRAF"
