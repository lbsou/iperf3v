# iperf3v

> **English summary.** iperf3v is a maintained fork of [ESnet iperf3](https://github.com/esnet/iperf).
> It adds a Windows/Cygwin port (high-resolution rate timer, TransmitFile zero-copy, non-fatal DSCP,
> working `--cntl-ka`) and UDP resilience fixes for unstable links (out-of-order packets in `--bidir`,
> lost UDP connect reply). It interoperates with ESnet iperf3 in both directions (limits listed in
> `PATCHLOG`). The binary is
> named `iperf3v` so it never clashes with a distribution's `iperf3` package. Generic fixes are proposed
> upstream. License: BSD (see `LICENSE`), copyright The Regents of the University of California (LBNL/ESnet).

Fork maintenu d'iperf3 (ESnet). Le `README.md` d'origine reste intact ; ce fichier décrit seulement
ce qui diffère.

## Ce qui change par rapport à ESnet

La liste à jour des patchs, avec leur statut en amont, est dans [`PATCHLOG`](PATCHLOG). En résumé :

- **Windows / Cygwin** : minuterie haute résolution pour le débit cible, TransmitFile (zéro copie),
  DSCP non bloquant, `--cntl-ka` disponible.
- **UDP sur liens instables** : tolérance aux paquets hors ordre en `--bidir` ; renvoi du message
  « connect » UDP quand la réponse se perd.
- **Interopérabilité** : un `iperf3v` fonctionne face à un iperf3 ESnet, dans les deux sens. Les
  correctifs qui demandent `iperf3v` aux deux bouts retombent sur le comportement d'origine sinon.
  Les limites connues sont dans la section « Known issues » et les notes du `PATCHLOG`.
- **Serveur Windows** : en UDP, un serveur Windows ne gère pas encore plus d'une socket de flux
  (`-P 2`, `--bidir`) ; voir « Known issues ».

## Versions

`<tag ESnet>-vN` : `3.22.1-v1` est la première version d'iperf3v sur le tag ESnet `3.22.1`.
`N` augmente à chaque publication sur le même tag et revient à 1 sur un nouveau tag ESnet.
`iperf3v --version` l'affiche. Tag Git de publication : `v3.22.1-v1`.

## Compiler

Linux :

```sh
./configure --disable-shared --program-transform-name='s/^iperf3$/iperf3v/'
make && sudo make install
```

Windows (Cygwin, paquets `gcc-core make libssl-devel zlib-devel`) :

```sh
./configure --with-openssl=/usr && make
cp src/.libs/iperf3.exe iperf3v.exe   # ou src/iperf3.exe selon la présence de .libs
```

À livrer à côté de `iperf3v.exe` : `cygwin1.dll`, `cygcrypto-3.dll`, `cygz.dll`.
`configure` doit afficher `checking TCP_KEEPIDLE socket option... yes`.

Les binaires prêts à l'emploi sont dans les Releases GitHub.

## Branches

- `master` : miroir intact d'ESnet (mis à jour par « Sync fork »).
- `fork/<tag ESnet>` (ex. `fork/3.22.1`) : le tag ESnet, puis la série de patchs, un patch par commit,
  préfixé `windows:`, `fix:`, `feature:` ou `fork:`. **Une branche `fork/*` publiée n'est jamais
  réécrite** : une correction s'ajoute en commit `fixup! <titre du patch>`, et la série n'est nettoyée
  qu'au portage vers le tag ESnet suivant (nouvelle branche `fork/<nouveau tag>`).
- Pour épingler une version, utiliser un tag `v<version>`, pas une branche.

## Suivi d'ESnet et tickets

Chaque semaine, un ticket « Veille ESnet » liste les tickets, PR et versions d'ESnet nouveaux ou
modifiés, ceux qui touchent nos zones (UDP, connect, bidir, keepalive, Windows…) en premier. Le tri se
fait à la main avec les étiquettes :

- `amont:à-intégrer` : on reprend le correctif d'ESnet dans notre série sans attendre sa fusion ;
- `amont:à-suivre` ;
- `amont:ignoré`.

Une nouvelle version ESnet ouvre un ticket « Porter vers <tag> » avec un essai automatique de la série
sur ce tag. Pour signaler un bug d'iperf3v, utiliser le modèle « Bug » (`iperf3v --version` exigé).
