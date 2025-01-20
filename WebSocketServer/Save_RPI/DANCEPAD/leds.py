from machine import Pin
import neopixel
import time

# Configuration
LED_PIN = 2       # GPIO où le bandeau LED est connecté
NUM_PIXELS = 300    # Nombre de LEDs dans le bandeau (ajustez selon votre bandeau)
np = neopixel.NeoPixel(Pin(LED_PIN), NUM_PIXELS)

# Fonction pour définir une couleur unique sur toutes les LEDs
def set_color(color):
    for i in range(NUM_PIXELS):
        np[i] = color
    np.write()

# Mode: Effet de déplacement d'un point lumineux
def moving_point(color, delay=0.03):
    for i in range(NUM_PIXELS):
        np.fill((0, 0, 0))  # Éteint toutes les LEDs
        np[i] = color       # Allume une LED
        np.write()
        time.sleep(delay)

# Mode: Effet de remplissage progressif
def filling_effect(color, delay=0.03):
    for i in range(NUM_PIXELS):
        np[i] = color  # Ajoute une LED allumée
        np.write()
        time.sleep(delay)

# Mode: Arc-en-ciel
def wheel(pos):
    """Génère des couleurs arc-en-ciel"""
    if pos < 85:
        return (pos * 3, 255 - pos * 3, 0)
    elif pos < 170:
        pos -= 85
        return (255 - pos * 3, 0, pos * 3)
    else:
        pos -= 170
        return (0, pos * 3, 255 - pos * 3)

def rainbow_cycle(delay=0.01):
    for j in range(255):
        for i in range(NUM_PIXELS):
            pixel_index = (i * 256 // NUM_PIXELS) + j
            np[i] = wheel(pixel_index & 255)
        np.write()
        time.sleep(delay)

# Mode: Chemin unique avec point lumineux
def single_path(color, delay=0.1):
    for i in range(NUM_PIXELS):
        np.fill((0, 0, 0))
        np[i] = color
        np.write()
        time.sleep(delay)

# Mode: Chemin unique avec remplissage
def single_filling(color, delay=0.1):
    for i in range(NUM_PIXELS):
        np[i] = color
        np.write()
        time.sleep(delay)

def blink_thirty_percent_white(blink_times=3, on_delay=0.5, off_delay=0.5):
    """
    Fait clignoter 30% des LEDs du bandeau en blanc.
    - blink_times : nombre de clignotements
    - on_delay    : durée (en s) lorsque les LEDs sont allumées
    - off_delay   : durée (en s) lorsque les LEDs sont éteintes
    """
    import urandom  # pour tirage pseudo-aléatoire (ou random sur MicroPython si disponible)
    
    print("blinked")
    
    count = int(NUM_PIXELS * 0.3)  # 30% des LEDs
    if count < 1:
        count = 1

    for _ in range(blink_times):
        # Sélection aléatoire de 'count' positions dans le bandeau
        # Pour ne pas tirer deux fois le même index, on peut créer une liste d'index
        indices_disponibles = list(range(NUM_PIXELS))
        # On mélange les indices
        for i in range(len(indices_disponibles) - 1, 0, -1):
            j = urandom.getrandbits(16) % (i + 1)
            indices_disponibles[i], indices_disponibles[j] = indices_disponibles[j], indices_disponibles[i]

        # On prend les 'count' premiers de cette liste
        selection = indices_disponibles[:count]

        # Allume uniquement les LEDs sélectionnées
        np.fill((0, 0, 0))   # Éteint tout
        for i in selection:
            np[i] = (255, 255, 255)  # Blanc
        np.write()
        time.sleep(on_delay)

        # Éteint toutes les LEDs
        np.fill((0, 0, 0))
        np.write()
        time.sleep(off_delay)


