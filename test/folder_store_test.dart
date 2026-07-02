import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_tracker/data/folder_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FolderStore.all.value = [];
  });

  test('create, toggle membership, rename and delete a folder', () async {
    final f = await FolderStore.create('Date nights', emoji: '💑');
    expect(FolderStore.all.value.length, 1);
    expect(f.emoji, '💑');

    await FolderStore.toggle(f.id, 'r1');
    await FolderStore.toggle(f.id, 'r2');
    expect(FolderStore.byId(f.id)!.restaurantIds, ['r1', 'r2']);
    expect(FolderStore.contains(f.id, 'r1'), true);

    await FolderStore.toggle(f.id, 'r1'); // remove
    expect(FolderStore.byId(f.id)!.restaurantIds, ['r2']);

    await FolderStore.rename(f.id, 'Anniversaries', '🎉');
    expect(FolderStore.byId(f.id)!.name, 'Anniversaries');
    expect(FolderStore.byId(f.id)!.emoji, '🎉');

    await FolderStore.delete(f.id);
    expect(FolderStore.all.value, isEmpty);
  });

  test('folders survive a save/load round-trip', () async {
    final f = await FolderStore.create('Pizza tour', emoji: '🍕');
    await FolderStore.toggle(f.id, 'abc');

    FolderStore.all.value = []; // wipe memory
    await FolderStore.load(); // reload from prefs
    expect(FolderStore.all.value.length, 1);
    expect(FolderStore.all.value.first.name, 'Pizza tour');
    expect(FolderStore.all.value.first.restaurantIds, ['abc']);
  });
}
