# Mini-Lab Réseau — Configuration & Tests (Packet Tracer)

---

## 1. Objectif du projet

Configurer un réseau d'entreprise sous Packet Tracer respectant les contraintes de segmentation VLAN, avec :

- Routage inter-VLAN via routeur Cisco 1941
- DHCP centralisé sur le routeur (un pool par VLAN)
- Accès Internet
- Tests de connectivité entre VLAN et vers Internet

---

## 2. Matériel utilisé

| Équipement | Quantité | Rôle |
|---|---|---|
| Routeur Cisco 1941 | 1 | Routage inter-VLAN, DHCP, NAT/PAT |
| Switch PT | 3 | Distribution VLAN (config identique) |
| Point d'accès Wi-Fi PT-AC | 3 | Couverture Wi-Fi (VLAN 20) |
| PC portable | 3 | Clients Wi-Fi |
| PC fixe | 6 | Postes de travail (VLAN 10) |
| Téléphone IP Cisco 7960 | 3 | VoIP (VLAN 1) |
| PC test "Internet" (hôte) | 1 | Simule le WAN (10.0.0.2) |

> **Note** : Les 3 switches utilisent une configuration **identique**. Un seul fichier d'export de configuration switch est fourni (`export config switch.txt`).

---

## 3. Fichiers du dépôt GitHub

| Fichier | Description |
|---|---|
| `README.md` | Ce document |
| `export config router.txt` | Configuration complète du routeur Cisco 1941 |
| `export config switch.txt` | Configuration d'un switch (identique sur les 3) |
| `TEST_LUIGI_DENIS_LAPLATEFORME.pkt` | Fichier Packet Tracer |

---

## 4. Plan d'adressage et segmentation VLAN

### Réseaux LAN (VLAN)

| VLAN | Usage | Réseau | Gateway  | Plage DHCP |
|------|-------|--------|--------------|------------|
| 1 | VoIP (téléphones IP Cisco 7960) | 192.168.0.0/24 | 192.168.0.254 | .10 – .50 |
| 10 | PC fixes | 192.168.10.0/24 | 192.168.10.254 | .10 – .50 |
| 20 | Wi-Fi (points d'accès) | 192.168.20.0/24 | 192.168.20.254 | .10 – .50 |
| 30 | Administration | 192.168.30.0/24 | 192.168.30.254 | .10 – .50 |
| 999 | VLAN natif (trunk) | — | Pas d'IP | — |

### Côté WAN

| Élément | IP |
|---|---|
| Gi0/0 du routeur (côté WAN) | 10.0.0.1/8 |
| PC hôte "Internet" | 10.0.0.2/8 |

### Adresses reservées (exclues du DHCP)

Pour chaque VLAN, les plages `.1 – .9` et `.51 – .254` sont exclues du DHCP afin que le serveur DHCP distribue les adresses IP sur la plage `.10 – .50`

---
## 5. Schéma logique

```text

┌─────────────────────────────────────────────────────────────────────────────┐
│                        INTERNET (WAN)                                       │
│                     PC Hôte : 10.0.0.2                                      │
│                Passerelle par défaut : 10.0.0.1                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ 
                                    │
                    [Gi0/0: 10.0.0.1]  ←─── NAT Outside
                         ROUTEUR CISCO 1941
                    ┌───────────────────────────────────┐ 
                    │  SERVICES :                       │
                    │  • Routage Inter-VLAN (SVI)       │
                    │  • DHCP 4 pools (.10–.50/VLAN)    │
                    │  • NAT/PAT overload               │
                    │                                   │
                    │  GATEWAYS (SVI) :                 │
                    │  • Vlan1  : 192.168.0.254   VoIP  │
                    │  • Vlan10 : 192.168.10.254  PC    │
                    │  • Vlan20 : 192.168.20.254  Wi-Fi │
                    │  • Vlan30 : 192.168.30.254  Admin │
                    │                                   │
                    │  HWIC-4ESW (module 4 ports) :     │
                    │  • Fa0/0/0  trunk ────── Sw1      │
                    │  • Fa0/0/1  trunk ────── Sw2      │
                    │  • Fa0/0/2  trunk ────── Sw3      │
                    │  • Fa0/0/3  non utilisé           │
                    │  • Gi0/1    non utilisé           │
                    └───────────────────────────────────┘
                       │           │           │
           trunk (native VLAN 999, allowed VLAN 1,10,20,30)
                       │           │           │
              ┌────────┴──┐   ┌────┴────┐  ┌───┴────────┐
              │ Sw1       │   │ Sw2     │  │  Sw3       │
              └───────────┘   └─────────┘  └────────────┘

  CONFIG SWITCH (identique sur les 3) — affectation des ports :

  Port       VLAN             Usage
  ─────────────────────────────────────
  Gi1/1      trunk            uplink vers routeur (Fa0/0/0)
  Gi9/1      trunk            uplink secondaire
  Fa2/1      voice (VLAN 1)   Téléphones IP Cisco 7960
  Fa3/1      voice (VLAN 1)   Téléphones IP Cisco 7960
  Fa4/1      20               Points d'accès Wi-Fi
  Fa5/1      20               Points d'accès Wi-Fi
  Fa6/1      10               PC fixes
  Fa7/1      10               PC fixes
  Fa8/1      30               Administration

  Trunk : native VLAN 999 | allowed VLAN 1,10,20,30
  Voice : VLAN 1 sur les ports Fa2/1 et Fa3/1

```

**Conventions du schéma :**


- **Gi1/1** et **Gi9/1** sont les deux ports trunk du switch (vus depuis le switch : `GigabitEthernet1/1` et `GigabitEthernet9/1`).
- **Fa0/0/0 à Fa0/0/2** sont les ports trunk correspondants sur le module HWIC-4ESW du routeur.
- La configuration est **identique sur les 3 switches** : un seul fichier d'export `export config switch.txt` est fourni.
- Le **VLAN natif 999** est configuré sur tous les trunks, côté switch comme côté routeur.







## 6. Configuration du Switch (identique sur les 3)



### Trunks (uplinks vers le routeur)

```ios
interface GigabitEthernet1/1
 switchport trunk native vlan 999
 switchport trunk allowed vlan 1,10,20,30
 switchport mode trunk
!
interface GigabitEthernet9/1
 switchport trunk native vlan 999
 switchport trunk allowed vlan 1,10,20,30
 switchport mode trunk
```


- `switchport trunk native vlan 999` : Application d'une bonne pratique de sécurité
- `switchport trunk allowed vlan 1,10,20,30` : restreint les VLAN autorisés aux 4 VLAN actifs. Les autres sont implicitement bloqués (principe du moindre privilège).


### Ports voix (VoIP — VLAN 1)

```ios
interface FastEthernet2/1
 switchport mode access
 switchport voice vlan 1
!
interface FastEthernet3/1
 switchport mode access
 switchport voice vlan 1
```

- Les téléphones IP Cisco 7960 sont branchés sur ces ports.
- `switchport voice vlan 1` leur attribue le VLAN voix sans impacter le VLAN de données (accès).


### Ports Wi-Fi (VLAN 20 — AP)

```ios
interface FastEthernet4/1
 switchport access vlan 20
 switchport mode access
!
interface FastEthernet5/1
 switchport access vlan 20
 switchport mode access
```

- Les 3 points d'accès Wi-Fi PT-AC sont connectés sur ces ports.


### Ports PC fixes (VLAN 10)

```ios
interface FastEthernet6/1
 switchport access vlan 10
 switchport mode access
!
interface FastEthernet7/1
 switchport access vlan 10
 switchport mode access
```

- 2 PC fixes par switch connectés en VLAN 10.
- IP attribuée par le pool DHCP `PC_POOL` du routeur (plage .10–.50).

### Port Administration (VLAN 30)

```ios
interface FastEthernet8/1
 switchport access vlan 30
 switchport mode access
```


- Port dédié pour la console/gestion/admin.
- IP attribuée par le pool `ADMIN_POOL`.

### Récapitulatif des ports

| Plage de ports | VLAN | Usage |
|---|---|---|
| Fa2/1 – Fa3/1 | 1 (voice) | Téléphones IP Cisco 7960 |
| Fa4/1 – Fa5/1 | 20 | Points d'accès Wi-Fi |
| Fa6/1 – Fa7/1 | 10 | PC fixes |
| Fa8/1 | 30 | Administration |
| Gi1/1, Gi9/1 | trunk | Uplinks vers routeur |

---

## 7. Configuration du Routeur (Router-on-a-Stick / SVI)




### Interfaces trunk côté LAN (sub-interfaces)

```
interface FastEthernet0/0/0
 switchport trunk native vlan 999
 switchport mode trunk
!
interface FastEthernet0/0/1
 switchport trunk native vlan 999
 switchport mode trunk
!
interface FastEthernet0/0/2
 switchport trunk native vlan 999
 switchport mode trunk
!
interface FastEthernet0/0/3
 switchport mode access
```


- Les ports Fa0/0/0 à Fa0/0/2 sont configurés en trunk et connectés aux 3 switches.
- `switchport trunk native vlan 999` assure que le trafic natif de chaque switch utilise le VLAN 999 (aligné avec la config switch).
- Le port Fa0/0/3 reste en access (non utilisé dans ce projet).

### Interface WAN (Gi0/0)

```ios
interface GigabitEthernet0/0
 ip address 10.0.0.1 255.0.0.0
 ip nat outside
 duplex auto
 speed auto
```

- IP 10.0.0.1/8 côté WAN (vers le PC hôte 10.0.0.2).
- Marquée `ip nat outside` : c'est l'interface de sortie pour le NAT.

### SVI (Switched Virtual Interfaces) — Routage inter-VLAN

```ios
interface Vlan1
 ip address 192.168.0.254 255.255.255.0
 ip nat inside
!
interface Vlan10
 ip address 192.168.10.254 255.255.255.0
 ip nat inside
!
interface Vlan20
 ip address 192.168.20.254 255.255.255.0
 ip nat inside
!
interface Vlan30
 ip address 192.168.30.254 255.255.255.0
 ip nat inside
!
interface Vlan999
 no ip address
```


- Chaque SVI porte l'adresse IP de gateway de son VLAN.
- Marquée `ip nat inside` : le traffic provenant de ces réseaux vers l'extérieur est translaté.
- Vlan999 existe pour aligner le VLAN natif trunk


### Route par défaut (vers Internet)

```ios
ip route 0.0.0.0 0.0.0.0 10.0.0.2
```

- Le routeur utilise le PC hôte 10.0.0.2 comme passerelle par défaut (Internet simulé).

---

## 8. DHCP centralisé (sur le routeur)

### Exclusion des adresses reservées

```ios
ip dhcp excluded-address 192.168.0.1 192.168.0.9
ip dhcp excluded-address 192.168.0.51 192.168.0.254
ip dhcp excluded-address 192.168.10.1 192.168.10.9
ip dhcp excluded-address 192.168.10.51 192.168.10.254
ip dhcp excluded-address 192.168.20.1 192.168.20.9
ip dhcp excluded-address 192.168.20.51 192.168.20.254
ip dhcp excluded-address 192.168.30.1 192.168.30.9
ip dhcp excluded-address 192.168.30.51 192.168.30.254
```

Exlusion des plages IP .1 à 9 et de .51. à 254 


- Plage DHCP active : `.10 – .50` par VLAN.

### Pools DHCP

```ios
ip dhcp pool VOIP_POOL
 network 192.168.0.0 255.255.255.0
 default-router 192.168.0.254
!
ip dhcp pool PC_POOL
 network 192.168.10.0 255.255.255.0
 default-router 192.168.10.254
!
ip dhcp pool AP_POOL
 network 192.168.20.0 255.255.255.0
 default-router 192.168.20.254
!
ip dhcp pool ADMIN_POOL
 network 192.168.30.0 255.255.255.0
 default-router 192.168.30.254
```





---

## 9. NAT / PAT vers Internet

### Configuration NAT

```ios
ip access-list standard NAT_INTERNET
 permit 192.168.0.0 0.0.0.255
 permit 192.168.10.0 0.0.0.255
 permit 192.168.20.0 0.0.0.255
 permit 192.168.30.0 0.0.0.255
!
interface GigabitEthernet0/0
 ip nat outside
!
interface Vlan1
 ip nat inside
!
interface Vlan10
 ip nat inside
!
interface Vlan20
 ip nat inside
!
interface Vlan30
 ip nat inside
!
ip nat inside source list NAT_INTERNET interface GigabitEthernet0/0 overload
```


- L'ACL `NAT_INTERNET` autorise les 4 réseaux LAN à sortir vers Internet.
- Chaque SVI est marquée `ip nat inside` : le trafic originate de ces réseaux est sujet à translation.
- `Gi0/0` est marquée `ip nat outside` : c'est l'interface de sortie.
- `overload` active le PAT (Port Address Translation) : toutes les adresses locales (192.168.x.x) sont translatées en une seule inside global address (10.0.0.1).


---

## 10. Tests de connectivité réalisés

### Routage inter-VLAN (PC1 → tous les VLAN)

| Source | Destination | Résultat |
|--------|-------------|----------|
| PC1 (VLAN 10, 192.168.10.10) | 192.168.0.10 (VoIP) | ✅ Succès 4/4 |
| PC1 (VLAN 10, 192.168.10.10) | 192.168.0.11 (VoIP) | ✅ Succès 4/4 |
| PC1 (VLAN 10, 192.168.10.10) | 192.168.0.12 (VoIP) | ✅ Succès 4/4 |
| PC1 (VLAN 10, 192.168.10.10) | 192.168.30.10 (Admin) | ✅ Succès 4/4 |

### Accès Internet via NAT/PAT

| Source | Destination  | Résultat |
|--------|-------------|-----------|
| PC1 (192.168.10.10) | 10.0.0.2 (Internet)| ✅ Succès 4/4 |


### DHCP — Attribution d'adresses

| Type d'équipement | VLAN | IP reçue | Résultat |
|---|---|---|---|
| PC fixe | 10 | 192.168.10.10 | ✅ OK |
| Laptop Wi-Fi | 20 | 192.168.20.10 | ✅ OK |
| PC Admin | 30 | 192.168.30.10 | ✅ OK |

### Conclusion des tests

✅ **Routage inter-VLAN** : fonctionnel (PC1 accède à VoIP, Admin)  
✅ **Accès Internet (NAT/PAT)** : fonctionnel (PC1 ping 10.0.0.2, PAT overload actif)  
✅ **DHCP** : fonctionnel (les 3 types de clients recoivent les bonnes IPs dans les bonnes plages)

---

## 12. Choix de sécurité 

> ⚠️ Les options de sécurité suivantes ont été **volontairement désactivées** afin de faciliter l'évaluation de l'évaluateur sans friction. En production, elles seraient impérativement activées.

| Option | État | Raison |
|---|---|---|
| `service password-encryption` | **Non activé** | Permet de lire les mots de passe en clair dans les exports de config (facilite l'évaluation et le débogage) |
| `port-security` / `sticky MAC` | **Non activé** | Évite de verrouiller les ports sur des MAC spécifiques qui pourraient changer durant les tests |
| Mots de passe console / VTY / enable | **Non configurés** | L'évaluateur peut accéder directement aux équipements sans connaître de credentials |





## Résumé de la configuration

| Élément | Détail |
|---|---|
| VLAN | 1 (VoIP), 10 (PC), 20 (Wi-Fi), 30 (Admin), 999 (natif) |
| Routage | SVI sur routeur 1941 (router-on-a-stick) |
| DHCP | 4 pools sur le routeur (plage .10–.50 par VLAN) |
| NAT/PAT | Overload sur Gi0/0, ACL NAT_INTERNET |
| Trunks | Native VLAN 999, VLANs autorisés 1,10,20,30 |
| Sécurité | Désactivée intentionnellement pour l'évaluation |