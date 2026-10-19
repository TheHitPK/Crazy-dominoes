extends RefCounted
## Configuración del juego en línea. Es el único sitio donde hay que tocar si
## el servidor cambia de dirección.

## Dirección del servidor de salas para jugar a distancia (el de Render).
## Con esto puesto, los jugadores no escriben ninguna dirección: uno pulsa
## "Crear sala" y los demás solo ponen el código.
## Si se deja vacía (""), la pantalla vuelve a pedir la dirección a mano.
const SERVER_URL := "crazy-dominoes.onrender.com"
