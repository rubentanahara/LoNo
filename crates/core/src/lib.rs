pub mod note;

pub fn add(left: u64, right: u64) -> u64 {
    left + right
}

pub fn double(value: u64) -> u64 {
    value * 2
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }

    #[test]
    fn doubles() {
        assert_eq!(double(21), 42);
    }
}
