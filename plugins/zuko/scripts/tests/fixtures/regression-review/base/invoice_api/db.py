"""Queries go through run(), which passes values as parameters. raw() is for fixed SQL."""
import psycopg

from .settings import DATABASE_URL

DatabaseError = psycopg.Error


def run(sql, params=()):
    with psycopg.connect(DATABASE_URL) as conn, conn.cursor() as cursor:
        cursor.execute(sql, params)
        return cursor.fetchall()


def raw(sql):
    with psycopg.connect(DATABASE_URL) as conn, conn.cursor() as cursor:
        cursor.execute(sql)
        return cursor.fetchall()
