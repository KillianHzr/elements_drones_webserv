# main.py

from machine import Pin
import time
import json
from websocket_client import WebSocketClient
from leds import blink_thirty_percent_white  # On importe la même fonction d'animation que sur "buzzers"
import _thread

# Définition des boutons sur des GPIOs
button1 = Pin(33, Pin.IN, Pin.PULL_UP)
button2 = Pin(32, Pin.IN, Pin.PULL_UP)
button3 = Pin(12, Pin.IN, Pin.PULL_UP)
button4 = Pin(27, Pin.IN, Pin.PULL_UP)

# Fonction pour lire l'état des boutons
def read_buttons():
    b1 = not button1.value()
    b2 = not button2.value()
    b3 = not button3.value()
    b4 = not button4.value()
    return b1, b2, b3, b4

# Configuration du WebSocket
url = "ws://192.168.10.213:8080/dancePadConnect"
ws = WebSocketClient(url)

print("Connexion au serveur WebSocket (dancePadConnect) ...")
if ws.connect():
    print("Connecté au serveur WebSocket (dancePadConnect)")
else:
    print("Échec de connexion au serveur WebSocket (dancePadConnect)")

# Thread pour recevoir les messages du serveur WebSocket
def websocket_receiver():
    """
    Thread chargé de recevoir et traiter les messages du serveur.
    S'inspire de la logique du code 'buzzers' :
    - Décodage JSON
    - Détection du type "confirmSoluce"
    - Lancement de l'animation blink_thirty_percent_white
    """
    while True:
        try:
            message = ws.receive()
            if message:
                print("Message reçu du WS:", message)
                try:
                    data = json.loads(message)
                    # Si on détecte la même info que sur le "buzzers" (type = confirmSoluce)
                    if data.get("type") == "confirmSoluce":
                        print("Lancement de l'animation confirmSoluce (dancepad) !")
                        blink_thirty_percent_white(blink_times=5, on_delay=0.2, off_delay=0.2)
                except json.JSONDecodeError:
                    print("Erreur de décodage JSON:", message)
        except OSError as e:
            # On ignore les erreurs de timeout ou de déconnexion momentanée
            pass
        except Exception as e:
            print("Erreur dans la réception WebSocket (dancepad):", e)

# Lancement du thread pour la réception WebSocket
_thread.start_new_thread(websocket_receiver, ())

# À l'initialisation : envoyer "released" pour tous les boutons
for i in range(4):
    data = {'button': i + 1, 'state': 'released'}
    ws.send(json.dumps(data))
    print(f"État initial 'released' envoyé pour le bouton {i + 1}.")

# Écoute des boutons (boucle principale)
previous_states = (False, False, False, False)
try:
    while True:
        b1, b2, b3, b4 = read_buttons()
        current_states = (b1, b2, b3, b4)
        # On regarde si l'un des boutons a changé d'état
        if current_states != previous_states:
            for i, (prev, curr) in enumerate(zip(previous_states, current_states)):
                if not prev and curr:
                    # Bouton pressé
                    data = {'button': i + 1, 'state': 'pressed'}
                    ws.send(json.dumps(data))
                    print(f"Bouton {i + 1} pressé, envoyé au serveur.")
                elif prev and not curr:
                    # Bouton relâché
                    data = {'button': i + 1, 'state': 'released'}
                    ws.send(json.dumps(data))
                    print(f"Bouton {i + 1} relâché, envoyé au serveur.")
            previous_states = current_states

        time.sleep(0.1)  # Petit délai pour éviter de saturer la boucle
except KeyboardInterrupt:
    print("Arrêt de la surveillance des boutons (CTRL+C).")
finally:
    ws.close()
    print("Connexion WebSocket fermée.")

