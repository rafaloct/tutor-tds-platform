import unittest
from qa_snapshot_audit import rows

class DumpRowsTest(unittest.TestCase):
    def test_multiple_rows(self):
        self.assertEqual(rows("(1,'a','b','yes'),(2,'c','d','no')"),[['1','a','b','yes'],['2','c','d','no']])
    def test_quoted_comma_and_parenthesis(self):
        self.assertEqual(rows("(1,'a,(b)','value')")[0][1],'a,(b)')
    def test_escaped_quote_and_backslash(self):
        self.assertEqual(rows(r"(1,'a\'b','c\\d')"),[['1',"a'b",'c\\d']])
    def test_truncation_rejected(self):
        with self.assertRaises(ValueError): rows("(1,'a")
    def test_sql_expression_rejected(self):
        with self.assertRaises(ValueError): rows('(1,concat(2))')
    def test_trailing_command_rejected(self):
        with self.assertRaises(ValueError): rows("(1,'a'); DROP TABLE users;")

if __name__=='__main__': unittest.main()
