# Firestore schema

```
users/{uid}
  name, username, bio, categoriesViewable (bool),
  defaultVisibility ('friends'|'private'), createdAt

  friends/{friendUid}         -> { name, username, since }
  friendRequests/{fromUid}    -> { name, username, sentAt }

  restaurants/{restaurantId}  -> mirrors the local Restaurant.toMap() fields:
      name, address, placeId, lat, lng, photoUrl (Storage URL),
      categoryKeys[], visits[] (each with visibility per visit),
      isFavorite, isChain, chainName, locationLabel,
      visibility ('friends'|'private')  // doc-level: max of its visits
      createdAt, updatedAt

  categories/{categoryId}     -> { key, label, iconIndex }
  folders/{folderId}          -> { name, emoji, restaurantIds[] } (private)

usernames/{username}          -> { uid }   // for add-by-username lookup
```

Photos upload to Storage at `users/{uid}/photos/{photoId}.jpg`; the local
path fields are replaced with download URLs when synced.

Sync strategy: local SQLite stays the source of truth for *your* data
(offline-first). A sync service pushes your changes up and mirrors friends'
"friends"-visible restaurants into memory for the feed, map, and friend
profiles — replacing today's mock `SocialService`.
