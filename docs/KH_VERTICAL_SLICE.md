# Kingdom Hearts Vertical Slice

This route is the smallest complete shop-to-expedition-to-shop loop. It uses the normal game menus and save slots; the editor and Live Developer Hub are not required.

## Controls

- Move: WASD or arrow keys
- Interact: E
- Dungeon attack: J
- Special: K
- Dodge: L
- Use expedition item: I
- Finisher: U

## Complete play route

1. Launch the game, select **New Game**, and choose a save slot. Continue through the opening dialogue until the Crossroads plaza appears.
2. Walk to the building labeled **Item Shop** at the upper-left of the plaza and press E at its entrance.
3. Read the first-shop guide. A new game starts with three Potions, two Ethers, two Gold Coins, and Sora's equipped Kingdom Key.
4. Move one item stand so its layout persistence is exercised:
   - Walk to **Rearrange furniture** near the lower-right of the shop and press E.
   - Click a highlighted stand, move the pointer to a valid green position, and click again.
   - Press E to finish rearranging.
5. Walk to the moved stand until **[E] Display slot** appears. Press E and choose a Potion, Ether, or Gold Coin.
6. Walk to the counter at the top-center, press E on **Open the shop**, and confirm the one-period cost.
7. The first session has one Moogle Broker. The customer walks to a live furniture browse point, inspects a displayed item, and opens negotiation.
8. Propose the shown price or accept the customer's counteroffer. A completed purchase removes the displayed item and adds the sale price to the shop's gold.
9. Wait for the customer to leave, review the session summary, and select **Continue**. The shop advances one time period.
10. Leave through the bottom-center shop door to return to the Crossroads.
11. Walk north to **World Bridge Gates**, press E, and choose **Expedition** for Traverse Town.
12. Sora is selected for the first Kingdom Hearts expedition. Optionally add a Potion or Ether, then choose **Depart: Short Traverse Town Run** and confirm the two-period cost.
13. In the arrival plaza, walk through the north opening after the **Room clear** message.
14. In the open combat room, defeat the single Shadow with J attacks. The enemy is a placeholder-safe `shadow_heartless` using the existing combat system.
15. Walk over the labeled **LUCID SHARD** pickup. The north exit stays locked until the guaranteed shard is collected.
16. Walk through the north opening. The expedition summary confirms the loot, and the Lucid Shard is transferred into shop storage. Select **Return to the Crossroads**.
17. Re-enter the Item Shop, place the Lucid Shard on any display stand, and open the shop again. The Moogle Broker returns for this first recovered-item sale. Complete the negotiation.
18. Select **Menu** at the upper-right, choose **Save to slot** (normally the slot used for New Game), open **Menu** again, and choose **Quit to main menu**. Select **Load** and load that slot. Gold, storage, furniture position, displayed items, chapter state, and completion flags use the existing save document.

## What is deliberately outside this slice

- The five-room Traverse Town boss expedition and World Shard gate repair are later Chapter 1 acceptance work.
- No other franchise worlds are required.
- No tile painting, location-editor work, or Asset Factory work is required.
- Missing Lucid Shard/customer art uses the project's normal placeholder fallback.

## Automated acceptance

Run:

```powershell
& '.\tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/test_kh_vertical_slice.tscn
```

`KH_VERTICAL_SLICE_PASS` verifies starter inventory, movable furniture, dynamic customer targeting, both sales, the two-room live dungeon, Sora combat, the guaranteed pickup, expedition loot banking, and a save/load roundtrip.

Human acceptance is still required. Record only the largest observed issues: item-placement clarity, customer movement, dungeon-exit clarity, and sale-screen presentation.
