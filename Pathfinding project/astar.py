import pygame
import math
from queue import PriorityQueue
import json
import os
import glob

pygame.init()

WIDTH = 800
WIN = pygame.display.set_mode((WIDTH, WIDTH))
pygame.display.set_caption("A* Path Finding Algorithm with Save/Load Support")

# Font za koordinate
FONT = pygame.font.SysFont("Arial", 8)
# Font za vnos imena
INPUT_FONT = pygame.font.SysFont("Arial", 24)
# Font za seznam labirintov
LIST_FONT = pygame.font.SysFont("Arial", 20)

# Barve
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 255, 0)
YELLOW = (255, 255, 0)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
PURPLE = (128, 0, 128)
ORANGE = (255, 165 ,0)
GREY = (128, 128, 128)
TURQUOISE = (64, 224, 208)
LIGHT_BLUE = (173, 216, 230)
BUTTON_GREEN = (0, 200, 0)
BUTTON_RED = (200, 0, 0)

# Izvor koordinat (0,0)
origin = (0, 0)

# Ena mreža predstavlja premik 0.5
TILE_UNIT = 0.5


class Spot:
    def __init__(self, row, col, width, total_rows):
        self.row = row
        self.col = col
        self.x = row * width
        self.y = col * width
        self.color = WHITE
        self.neighbors = []
        self.width = width
        self.total_rows = total_rows

    def get_pos(self):
        return self.row, self.col

    def is_closed(self):
        return self.color == RED

    def is_open(self):
        return self.color == GREEN

    def is_barrier(self):
        return self.color == BLACK

    def is_start(self):
        return self.color == ORANGE

    def is_end(self):
        return self.color == TURQUOISE

    def reset(self):
        self.color = WHITE

    def make_start(self):
        self.color = ORANGE

    def make_closed(self):
        self.color = RED

    def make_open(self):
        self.color = GREEN

    def make_barrier(self):
        self.color = BLACK

    def make_end(self):
        self.color = TURQUOISE

    def make_path(self):
        self.color = PURPLE

    def draw(self, win):
        pygame.draw.rect(win, self.color, (self.x, self.y, self.width, self.width))

        # Izračun x,y koordinat za prikaz
        rel_x = (self.row - origin[0]) * TILE_UNIT
        rel_y = (self.col - origin[1]) * TILE_UNIT

        text_surface = FONT.render(f"{rel_x:.1f},{rel_y:.1f}", True, BLACK)
        text_rect = text_surface.get_rect(center=(self.x + self.width/2, self.y + self.width/2))
        win.blit(text_surface, text_rect)

    def update_neighbors(self, grid):
        self.neighbors = []
        if self.row < self.total_rows - 1 and not grid[self.row + 1][self.col].is_barrier():
            self.neighbors.append(grid[self.row + 1][self.col])  # DOWN
        if self.row > 0 and not grid[self.row - 1][self.col].is_barrier():
            self.neighbors.append(grid[self.row - 1][self.col])  # UP
        if self.col < self.total_rows - 1 and not grid[self.row][self.col + 1].is_barrier():
            self.neighbors.append(grid[self.row][self.col + 1])  # RIGHT
        if self.col > 0 and not grid[self.row][self.col - 1].is_barrier():
            self.neighbors.append(grid[self.row][self.col - 1])  # LEFT

    def __lt__(self, other):
        return False


def h(p1, p2):
    x1, y1 = p1
    x2, y2 = p2
    return abs(x1 - x2) + abs(y1 - y2)


# ============================
#         SHARANJE POTI
# ============================

def reconstruct_path(came_from, current, draw):
    global origin
    path = []

    while current in came_from:
        path.append(current.get_pos())
        current = came_from[current]
        current.make_path()
        draw()

    path.append(current.get_pos())
    path.reverse()

    path_coords = []
    for r, c in path:
        x = round((r - origin[0]) * TILE_UNIT, 1)
        y = round((c - origin[1]) * TILE_UNIT, 1)
        path_coords.append((x, y))

    # Zapišemo v datoteko
    with open("pot.txt", "w") as f:
        for x, y in path_coords:
            f.write(f"{x},{y}\n")

    print("Najdena pot:", path_coords)
    print("Pot shranjena v pot.txt")

    return path_coords


# ============================
#     SHRANI IN NALOŽI MAPO
# ============================

def save_map(grid, start, end, filename="map.json"):
    data = {
        "rows": len(grid),
        "start": start.get_pos() if start else None,
        "end": end.get_pos() if end else None,
        "walls": [],
        "origin": origin  # Shranimo tudi izhodišče
    }

    for row in grid:
        for spot in row:
            if spot.is_barrier():
                data["walls"].append(spot.get_pos())

    with open(filename, "w") as f:
        json.dump(data, f, indent=4)

    print(f"Mapa shranjena v {filename}")


def load_map(grid, filename="map.json"):
    global origin
    
    if not os.path.exists(filename):
        print(f"{filename} ne obstaja!")
        return None, None

    with open(filename, "r") as f:
        data = json.load(f)

    start_pos = data["start"]
    end_pos = data["end"]
    walls = data["walls"]
    
    # Naložimo izhodišče, če obstaja
    if "origin" in data:
        origin = tuple(data["origin"])

    # počisti mrežo
    for row in grid:
        for spot in row:
            spot.reset()

    start = None
    end = None

    # zidovi
    for r, c in walls:
        grid[r][c].make_barrier()

    # start
    if start_pos:
        sr, sc = start_pos
        start = grid[sr][sc]
        start.make_start()

    # end
    if end_pos:
        er, ec = end_pos
        end = grid[er][ec]
        end.make_end()

    print(f"Mapa {filename} uspešno naložena.")
    print(f"Izhodišče: {origin}")
    return start, end


# ============================
#           A*
# ============================

def algorithm(draw, grid, start, end):
    count = 0
    open_set = PriorityQueue()
    open_set.put((0, count, start))
    came_from = {}

    g_score = {spot: float("inf") for row in grid for spot in row}
    g_score[start] = 0

    f_score = {spot: float("inf") for row in grid for spot in row}
    f_score[start] = h(start.get_pos(), end.get_pos())

    open_set_hash = {start}

    while not open_set.empty():
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()

        current = open_set.get()[2]
        open_set_hash.remove(current)

        if current == end:
            return reconstruct_path(came_from, end, draw)

        for neighbor in current.neighbors:
            temp_g = g_score[current] + 1

            if temp_g < g_score[neighbor]:
                came_from[neighbor] = current
                g_score[neighbor] = temp_g
                f_score[neighbor] = temp_g + h(neighbor.get_pos(), end.get_pos())

                if neighbor not in open_set_hash:
                    count += 1
                    open_set.put((f_score[neighbor], count, neighbor))
                    open_set_hash.add(neighbor)
                    neighbor.make_open()

        draw()

        if current != start:
            current.make_closed()

    return False


# ============================
#          RISANJE
# ============================

def make_grid(rows, width):
    grid = []
    gap = width // rows

    for i in range(rows):
        grid.append([])
        for j in range(rows):
            grid[i].append(Spot(i, j, gap, rows))

    return grid


def draw_grid(win, rows, width):
    gap = width // rows
    for i in range(rows):
        pygame.draw.line(win, GREY, (0, i*gap), (width, i*gap))
        pygame.draw.line(win, GREY, (i*gap, 0), (i*gap, width))


def draw_button(win, x, y, width, height, color, text, text_color=BLACK):
    pygame.draw.rect(win, color, (x, y, width, height))
    pygame.draw.rect(win, BLACK, (x, y, width, height), 2)
    
    text_surface = LIST_FONT.render(text, True, text_color)
    text_rect = text_surface.get_rect(center=(x + width/2, y + height/2))
    win.blit(text_surface, text_rect)
    
    return pygame.Rect(x, y, width, height)


def draw(win, grid, rows, width, input_text="", file_list=None, selected_file=None):
    win.fill(WHITE)

    for row in grid:
        for spot in row:
            spot.draw(win)

    draw_grid(win, rows, width)
    
    # Prikaz vnosa imena
    if input_text != "":
        input_surface = INPUT_FONT.render(input_text, True, BLACK)
        win.blit(input_surface, (10, 10))
        pygame.draw.rect(win, BLACK, (5, 5, WIDTH-10, 30), 2)
    
    # Prikaz seznama datotek
    if file_list is not None:
        draw_file_list(win, file_list, selected_file)
    
    pygame.display.update()


def draw_file_list(win, file_list, selected_file):
    # Ozadje seznama
    list_width = 300
    list_height = 400
    list_x = WIDTH // 2 - list_width // 2
    list_y = WIDTH // 2 - list_height // 2
    
    pygame.draw.rect(win, LIGHT_BLUE, (list_x, list_y, list_width, list_height))
    pygame.draw.rect(win, BLACK, (list_x, list_y, list_width, list_height), 2)
    
    # Naslov
    title = LIST_FONT.render("Izberi labirint:", True, BLACK)
    win.blit(title, (list_x + 10, list_y + 10))
    
    # Elementi seznama
    for i, filename in enumerate(file_list):
        y_pos = list_y + 50 + i * 30
        color = BLUE if filename == selected_file else BLACK
        file_text = LIST_FONT.render(filename, True, color)
        win.blit(file_text, (list_x + 20, y_pos))
        
        # Oznaka izbrane datoteke
        if filename == selected_file:
            pygame.draw.rect(win, BLUE, (list_x + 10, y_pos, list_width - 20, 25), 2)
    
    # Gumba
    global confirm_button_rect, cancel_button_rect
    confirm_button_rect = draw_button(win, list_x + 50, list_y + list_height - 40, 80, 30, BUTTON_GREEN, "Potrdi")
    cancel_button_rect = draw_button(win, list_x + list_width - 130, list_y + list_height - 40, 80, 30, BUTTON_RED, "Prekliči")


def get_clicked_pos(pos, rows, width):
    gap = width // rows
    y, x = pos
    return y // gap, x // gap


# ============================
#           MAIN
# ============================

def main(win, width):
    global origin

    ROWS = 40
    grid = make_grid(ROWS, width)

    start = None
    end = None
    
    # Stanje vnosa imena
    input_active = False
    input_text = ""
    
    # Stanje seznama datotek
    show_file_list = False
    file_list = []
    selected_file = None

    run = True
    while run:
        draw(win, grid, ROWS, width, input_text if input_active else "", 
             file_list if show_file_list else None, selected_file)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                run = False

            # Vnos imena
            if input_active:
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_RETURN:
                        # Shrani z vnesenim imenom
                        if input_text:
                            filename = f"{input_text}.json"
                            save_map(grid, start, end, filename)
                        input_active = False
                        input_text = ""
                    elif event.key == pygame.K_BACKSPACE:
                        input_text = input_text[:-1]
                    else:
                        # Preveri, ali je znak dovoljen za ime datoteke
                        if event.unicode.isalnum() or event.unicode in ['_', '-']:
                            input_text += event.unicode
            
            # Seznam datotek
            elif show_file_list:
                if event.type == pygame.MOUSEBUTTONDOWN:
                    # Preveri, ali je klik na element seznama
                    list_width = 300
                    list_height = 400
                    list_x = WIDTH // 2 - list_width // 2
                    list_y = WIDTH // 2 - list_height // 2
                    
                    mouse_x, mouse_y = pygame.mouse.get_pos()
                    
                    if (list_x <= mouse_x <= list_x + list_width and 
                        list_y <= mouse_y <= list_y + list_height):
                        
                        # Izračun indeksa v seznamu
                        index = (mouse_y - list_y - 50) // 30
                        if 0 <= index < len(file_list):
                            selected_file = file_list[index]
                    
                    # Gumb za potrditev
                    if confirm_button_rect.collidepoint(mouse_x, mouse_y) and selected_file:
                        start, end = load_map(grid, selected_file)
                        show_file_list = False
                        selected_file = None
                    
                    # Gumb za preklic
                    if cancel_button_rect.collidepoint(mouse_x, mouse_y):
                        show_file_list = False
                        selected_file = None
            
            # Osnovni vmesnik
            else:
                # levi klik - samo če nismo v načinu urejanja
                if pygame.mouse.get_pressed()[0] and not input_active and not show_file_list:
                    row, col = get_clicked_pos(pygame.mouse.get_pos(), ROWS, width)
                    spot = grid[row][col]

                    # Če že imamo začetno in končno točko, dovolimo samo dodajanje ovir
                    if start and end:
                        if spot != start and spot != end:
                            spot.make_barrier()
                    else:
                        # Dovolimo postavljanje začetne in končne točke
                        if not start and spot != end:
                            start = spot
                            start.make_start()
                        elif not end and spot != start:
                            end = spot
                            end.make_end()
                        elif spot != start and spot != end:
                            spot.make_barrier()

                # desni klik - samo če nismo v načinu urejanja
                elif pygame.mouse.get_pressed()[2] and not input_active and not show_file_list:
                    row, col = get_clicked_pos(pygame.mouse.get_pos(), ROWS, width)
                    spot = grid[row][col]
                    spot.reset()
                    if spot == start: 
                        start = None
                    if spot == end: 
                        end = None

                # TIPKE
                if event.type == pygame.KEYDOWN:

                    # SPACE = A*
                    if event.key == pygame.K_SPACE and start and end:
                        for row in grid:
                            for spot in row:
                                spot.update_neighbors(grid)
                        algorithm(lambda: draw(win, grid, ROWS, width), grid, start, end)

                    # C = počisti
                    if event.key == pygame.K_c:
                        start = None
                        end = None
                        grid = make_grid(ROWS, width)

                    # R = prestavi koordinatno izhodišče
                    if event.key == pygame.K_r:
                        row, col = get_clicked_pos(pygame.mouse.get_pos(), ROWS, width)
                        origin = (row, col)
                        print("Novo izhodišče:", origin)

                    # S = shrani mapo z imenom
                    if event.key == pygame.K_s:
                        input_active = True
                        input_text = ""

                    # L = naloži mapo z izbiro
                    if event.key == pygame.K_l:
                        show_file_list = True
                        # Pridobi seznam JSON datotek
                        file_list = [f for f in os.listdir() if f.endswith('.json')]
                        selected_file = None

    pygame.quit()


main(WIN, WIDTH)