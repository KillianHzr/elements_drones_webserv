from machine import Pin
import time
import json
from websocket_client import WebSocketClient
import servo_motor  # votre fichier servo_motor.py
import _thread

# URL du websocket (changé pour la nouvelle route)
url = "ws://192.168.10.213:8080/dopamineConnect"

# Variable globale pour suivre l'état du bouton
button_pressed = False

# Fonction d'interruption pour le bouton
def handle_button(pin):
    global button_pressed
    button_pressed = True

# Fonction pour gérer les envois de messages WebSocket en réponse aux pressions de bouton
def button_handler():
    global button_pressed
    ws = WebSocketClient(url)
    if ws.connect():
        print("Connecté au serveur WebSocket (dopamineConnect)")
    else:
        print("Échec de connexion au serveur WebSocket dans button_handler")
        return  # Sort de la fonction si la connexion échoue

    try:
        while True:
            if button_pressed:
                button_pressed = False  # Réinitialisez l'état
                data = {"action": "dopamine", "state": "pressed"}
                ws.send(json.dumps(data))
                print("Bouton pressé, message envoyé au serveur.")
            time.sleep(0.1)  # Pause courte pour limiter l'utilisation du CPU
    except Exception as e:
        print(f"Erreur dans le thread button_handler: {e}")
    finally:
        ws.close()
        print("Connexion WebSocket fermée dans button_handler")

# Fonction pour gérer la réception des messages WebSocket
def websocket_receiver():
    ws = WebSocketClient(url)
    if ws.connect():
        print("Connecté au serveur WebSocket pour la réception")
    else:
        print("Échec de connexion au serveur WebSocket pour la réception")
        return  # Sort de la fonction si la connexion échoue

    try:
        while True:
            msg = ws.receive()
            if msg:
                print("Message reçu du serveur:", msg)
                try:
                    msg_data = json.loads(msg)
                    if msg_data.get("action") == "servo":
                        print("SERVO TURN")
                        servo_motor.run_servo_sequence()
                except Exception as e:
                    print(f"Erreur de traitement du message reçu : {e}")
            time.sleep(0.1)  # Pause courte pour limiter l'utilisation du CPU
    except Exception as e:
        print(f"Erreur dans le thread websocket_receiver: {e}")
    finally:
        ws.close()
        print("Connexion WebSocket fermée dans websocket_receiver")

# Configuration du bouton avec une interruption
button = Pin(18, Pin.IN, Pin.PULL_UP)
button.irq(trigger=Pin.IRQ_FALLING, handler=handle_button)

# Démarrer le thread pour gérer les envois de messages de bouton
try:
    _thread.start_new_thread(button_handler, ())
except Exception as e:
    print(f"Erreur de démarrage du thread button_handler: {e}")

# Démarrer le thread pour gérer la réception des messages WebSocket
try:
    _thread.start_new_thread(websocket_receiver, ())
except Exception as e:
    print(f"Erreur de démarrage du thread websocket_receiver: {e}")

# Boucle principale vide ou avec d'autres tâches
try:
    while True:
        time.sleep(1)  # Peut être remplacé par d'autres tâches si nécessaire
except KeyboardInterrupt:
    print("Arrêt du programme")

