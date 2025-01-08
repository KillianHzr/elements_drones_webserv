#
//  leds.py
//  WebSocketServer
//
//  Created by digital on 08/01/2025.
//

from machine import Pin
import neopixel
import time
import random
import math

# Configuration
LED_PIN = 2          # GPIO où le bandeau LED est connecté
NUM_PIXELS = 300     # Nombre de LEDs dans le bandeau (ajustez selon votre bandeau)
np = neopixel.NeoPixel(Pin(LED_PIN), NUM_PIXELS)

# Fonction pour définir une couleur unique sur toutes les LEDs
def set_color(color):
    for i in range(NUM_PIXELS):
        np[i] = color
    np.write()
    
def set_color_end(color):
    for i in range(NUM_PIXELS - 30, NUM_PIXELS):
        np[i] = color
    np.write()
        
# Mode: Allumer tout le bandeau en blanc avec intensité de 33%
def white_low_intensity():
    intensity = 30  # 33% de 255 (luminosité maximale)
    set_color((intensity, intensity, intensity))


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
        if i % 2 == 0:  # Allume une LED sur deux
            np[i] = color  # Ajoute une LED allumée
            np.write()
            time.sleep(delay)

# Mode: Animation de comète blanche superposée sur un fond rouge
def white_comet_over_red(base_colors, trail_length=10, delay=0.02):
    for i in range(NUM_PIXELS + trail_length):
        # Créer une copie de l'état de base
        display_colors = base_colors.copy()
        
        # Dessiner la comète blanche
        for j in range(trail_length):
            pos = i - j
            if 0 <= pos < NUM_PIXELS:
                brightness = 255 - (j * (255 // trail_length))  # Diminution progressive de la luminosité
                display_colors[pos] = (brightness, brightness, brightness)  # Comète blanche avec luminosité décroissante
        
        # Définir les couleurs LED individuellement
        for idx in range(NUM_PIXELS):
            np[idx] = display_colors[idx]
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

# Nouvelle animation: Remplir une LED sur deux en rouge à 50% puis envoyer des comètes blanches
def fill_red_with_white_comets(delay=0.03, trail_length=10, comet_delay=0.02):
    # Créer l'état de base avec une LED sur deux en rouge à 50%
    base_colors = [(127, 0, 0) if i % 2 == 0 else (0, 0, 0) for i in range(NUM_PIXELS)]
    
    # Définir les couleurs individuellement
    for i in range(NUM_PIXELS):
        np[i] = base_colors[i]
    np.write()
    time.sleep(1)  # Pause d'une seconde
    
    # Envoyer des comètes blanches par-dessus le fond rouge
    white_comet_over_red(base_colors, trail_length=trail_length, delay=comet_delay)

def triple_white_comet_on_red(base_color=(127, 0, 0), comet_color=(102, 102, 102),
                               comet_length=10, gap_length=15, delay=0.02):
    """
    Crée une animation de trois comètes blanches séparées par des LED rouges, se déplaçant ensemble.

    :param base_color: Couleur de fond (rouge par défaut à 50 % d'intensité, une LED sur deux)
    :param comet_color: Couleur des comètes (blanc par défaut)
    :param comet_length: Longueur de chaque comète
    :param gap_length: Nombre de LEDs rouges entre chaque comète
    :param delay: Temps de pause entre chaque mise à jour de l'animation
    """
    total_comet_length = (comet_length * 3) + (gap_length * 2)  # Longueur totale d'un "bloc"

    for i in range(NUM_PIXELS + total_comet_length):
        # Préparation d'un tableau de couleurs de base avec une LED rouge sur deux
        display_colors = [(base_color if idx % 2 == 0 else (0, 0, 0)) for idx in range(NUM_PIXELS)]

        for j in range(3):  # Trois comètes
            start_pos = i - (j * (comet_length + gap_length))

            for k in range(comet_length):  # Dessiner une comète blanche
                pos = start_pos + k
                if 0 <= pos < NUM_PIXELS:
                    brightness = int((255 - (k * (255 // comet_length))) * 0.4)  # Dégradé de luminosité à 40%
                    display_colors[pos] = (brightness, brightness, brightness)

        # Mise à jour des LEDs
        for idx in range(NUM_PIXELS):
            np[idx] = display_colors[idx]
        np.write()
        time.sleep(delay)
    
# *** Nouvelle Animation: LEDs rouges avec effet de respiration ***
def breathing_red_effect(duration=10):
    """
    Allume une LED sur deux en rouge avec un effet de respiration.
    Chaque LED a des paramètres de respiration aléatoires.
    
    :param duration: Durée de l'animation en secondes
    """
    # Identifier les LEDs rouges (une sur deux)
    red_leds = list(range(0, NUM_PIXELS, 2))  # Toutes les LEDs paires
    num_red_leds = len(red_leds)
    
    # Initialisation des paramètres aléatoires pour chaque LED rouge
    breathing_phases = [random.uniform(0, 2 * math.pi) for _ in red_leds]
    breathing_speeds = [random.uniform(0.02, 0.05) for _ in red_leds]  # Vitesse de respiration
    breathing_max_intensities = [random.randint(100, 255) for _ in red_leds]  # Intensité maximale
    
    start_time = time.time()
    
    while time.time() - start_time < duration:
        np.fill((0, 0, 0))  # Éteindre toutes les LEDs
        
        for idx, led in enumerate(red_leds):
            # Calculer la luminosité basée sur une onde sinusoïdale
            brightness = breathing_max_intensities[idx] * (math.sin(breathing_phases[idx]) * 0.5 + 0.5)
            brightness = int(brightness)
            np[led] = (brightness, 0, 0)  # Rouge avec luminosité variable
            
            # Mettre à jour la phase pour le prochain cycle
            breathing_phases[idx] += breathing_speeds[idx]
            if breathing_phases[idx] >= 2 * math.pi:
                breathing_phases[idx] -= 2 * math.pi
        
        np.write()
        time.sleep(0.03)  # Ajuster le délai pour contrôler la fluidité

