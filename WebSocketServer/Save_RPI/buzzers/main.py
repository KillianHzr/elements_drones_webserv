from machine import Pin
import time
import json
from websocket_client import WebSocketClient
from leds import blink_thirty_percent_white  # Import de la nouvelle fonction d'animation
import _thread

# Configuration des broches boutons (entrée avec pull-up)
boutons = [
    Pin(22, Pin.IN, Pin.PULL_UP),  # Bouton 1
    Pin(15, Pin.IN, Pin.PULL_UP),  # Bouton 2
    Pin(21, Pin.IN, Pin.PULL_UP),  # Bouton 3
    Pin(19, Pin.IN, Pin.PULL_UP),  # Bouton 4
    Pin(18, Pin.IN, Pin.PULL_UP)   # Bouton 5
]

# Configuration des LEDs (sortie)
leds = [
    Pin(4, Pin.OUT),   # LED 1
    Pin(16, Pin.OUT),  # LED 2
    Pin(17, Pin.OUT),  # LED 3
    Pin(2, Pin.OUT),   # LED 4
    Pin(5, Pin.OUT)    # LED 5
]

# État des LEDs (False = éteinte)
etat_leds = [False] * 5
for led, etat in zip(leds, etat_leds):
    led.value(etat)

# Pour stocker l'état précédent des boutons
old_btn_pressed = [False] * 5

# Connexion WebSocket
url = "ws://192.168.10.213:8080/buzzersEsp"
ws = WebSocketClient(url)
print("Connexion au serveur WebSocket (buzzersEsp) ...")

if ws.connect():
    print("Connecté au serveur WebSocket (buzzersEsp)")
else:
    print("Échec connexion (buzzersEsp)")
    raise SystemExit

# Fonction pour vérifier si un bouton est appuyé
def is_pressed(pin: Pin) -> bool:
    """
    Retourne True si le bouton est actuellement appuyé (état bas),
    False sinon.
    """
    return (pin.value() == 0)

def websocket_receiver():
    """Thread pour recevoir les messages du serveur WebSocket."""
    while True:
        try:
            message = ws.receive()
            if message:
                print("Message reçu du WS:", message)
                try:
                    data = json.loads(message)
                    if data.get("type") == "confirmSoluce":
                        print("Lancement de l'animation confirmSoluce !")
                        blink_thirty_percent_white(blink_times=5, on_delay=0.2, off_delay=0.2)
                except json.JSONDecodeError:
                    print("Erreur de décodage JSON:", message)
        except OSError as e:
            # Ignorer les erreurs de timeout
            pass
        except Exception as e:
            print("Erreur dans la réception WebSocket:", e)

# Lancer le thread pour la réception WebSocket
_thread.start_new_thread(websocket_receiver, ())

try:
    while True:
        # --- Gestion des boutons ---
        for i in range(5):
            # Lire l'état ACTUEL du bouton
            btn_pressed_now = is_pressed(boutons[i])

            # DÉTECTION TRANSITION : si on passe de 'non appuyé' à 'appuyé'
            if (not old_btn_pressed[i]) and btn_pressed_now:
                # L'utilisateur vient d'appuyer sur le bouton
                etat_leds[i] = not etat_leds[i]
                leds[i].value(etat_leds[i])
                print(f"Bouton {i + 1} pressé -> LED{i + 1} = {etat_leds[i]}")

                # Calcul de buzzersPressed
                pressed = sum(1 for etat in etat_leds if etat)

                data = {
                    "buzzersPressed": pressed,
                    "buzzersTotal": 5
                }
                ws.send(json.dumps(data))
                print(f"Envoi: {data}")

            # Mettre à jour l'état précédent
            old_btn_pressed[i] = btn_pressed_now

except KeyboardInterrupt:
    print("Arrêt du programme.")
finally:
    ws.close()
    print("Connexion WebSocket fermée.")

