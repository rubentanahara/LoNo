use time::OffsetDateTime;
use uuid::Uuid;

pub trait Clock {
    fn now(&self) -> OffsetDateTime;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NoteId(Uuid);

impl NoteId {
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }
}

impl Default for NoteId {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Document;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Note {
    pub id: NoteId,
    pub title: String,
    pub body: Document,
    pub created_at: OffsetDateTime,
    pub updated_at: OffsetDateTime,
}

impl Note {
    pub fn new(title: impl Into<String>, clock: &impl Clock) -> Self {
        let now = clock.now();
        Self {
            id: NoteId::new(),
            title: title.into(),
            body: Document,
            created_at: now,
            updated_at: now,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use time::macros::datetime;

    struct FixedClock(OffsetDateTime);

    impl Clock for FixedClock {
        fn now(&self) -> OffsetDateTime {
            self.0
        }
    }

    #[test]
    fn new_note_sets_title_and_matching_timestamps() {
        let now = datetime!(2026-01-01 12:00 UTC);
        let note = Note::new("Groceries", &FixedClock(now));

        assert_eq!(note.title, "Groceries");
        assert_eq!(note.body, Document);
        assert_eq!(note.created_at, now);
        assert_eq!(note.updated_at, now);
    }

    #[test]
    fn new_notes_get_distinct_ids() {
        let clock = FixedClock(datetime!(2026-01-01 12:00 UTC));

        assert_ne!(Note::new("a", &clock).id, Note::new("a", &clock).id);
    }
}
