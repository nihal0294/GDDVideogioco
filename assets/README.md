# Assets

Questa cartella raccoglie tutti i contenuti grafici e audio del progetto, inclusi i materiali di riferimento non utilizzati a runtime.

```text
assets/
|-- maps/                  # Asset specifici delle mappe
|-- characters/
|   |-- player/            # Player giocabile
|   |-- npcs/              # Personaggi non giocanti
|   `-- mobs/              # Mob e Astral
|-- environment/           # Props, vegetazione, edifici e terreno condiviso
|-- ui/                    # Texture, icone e font dell'interfaccia
|-- vfx/                   # Shader, particelle ed effetti visivi
|-- audio/                 # Music, ambience, SFX e voice
|-- shared/                # Materiali e texture realmente condivisi
`-- references/            # Concept, sorgenti e moodboard esclusi da Godot
```

Ogni pacchetto runtime conserva insieme modelli, texture, materiali e licenza. Per esempio, `maps/island/` contiene la grafica importata dell'isola; la scena e gli script restano invece in `game/world/maps/island/`.

Le cartelle sotto `references/` contengono concept art, screenshot, moodboard e file sorgente. Sono escluse dall'importazione tramite `.gdignore` e non devono essere referenziate dalle scene Godot.
