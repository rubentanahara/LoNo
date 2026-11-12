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
        assert_eq!(note.body, Document::default());
        assert_eq!(note.created_at, now);
        assert_eq!(note.updated_at, now);
    }

    #[test]
    fn new_notes_get_distinct_ids() {
        let clock = FixedClock(datetime!(2026-01-01 12:00 UTC));

        assert_ne!(Note::new("a", &clock).id, Note::new("a", &clock).id);
    }
}
