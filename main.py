def main():
    print("Hello from hot-stack!")


def add(a: int, b: int) -> int:
    return a + b


if __name__ == "__main__":
    main()
    add(34, 56)
    print(f"{add(34, 56)}")
