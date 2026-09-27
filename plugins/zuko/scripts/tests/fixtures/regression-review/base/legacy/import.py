"""One-off importer from the old billing system, run by hand."""
import sys

from invoice_api import db


def main(batch):
    return db.run("SELECT * FROM staging WHERE batch = '" + batch + "'")


if __name__ == "__main__":
    main(sys.argv[1])
