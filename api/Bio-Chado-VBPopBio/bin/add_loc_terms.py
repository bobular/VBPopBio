"""
Copies location terms from one ISA-Tab collection sheet to another.

For usage, run 'python3 add_loc_terms.py -h'.

This script stores the location terms for each unique location within
the source sheet and adds them to matching locations within the
destination sheet.  Only the terms from the first row of each unique
location within the source sheet will be used.  By default, if a
matching location is found in the destination file but it already has
some location terms filled in, it will not be changed.  The script takes
tab-delimited files by default and CSVs by option.

This script requires at least Python 3.5.
"""

import argparse
import csv
import os


def parse_args():
    """Parse the command line arguments."""
    parser = argparse.ArgumentParser(
        description='Copies location terms from one ISA-Tab collection sheet to another. This '
                    'script stores the location terms for each unique location within the source '
                    'sheet and adds them to matching locations within the destination sheet. Only'
                    ' the terms from the first row of each unique location within the source sheet'
                    ' will be used. By default, if a matching location is found in the destination'
                    ' file but it already has some location terms filled in, it will not be '
                    'changed.  The script takes tab-delimited files by default and CSVs by option.'
    )

    parser.add_argument('source_file', help='The file to get location terms from.')
    parser.add_argument('dest_file', help='The file to add location terms to.')
    parser.add_argument('--source-csv', action='store_const', const=',', default='\t',
                        dest='source_delim', help='Signal that the source file is a CSV.')
    parser.add_argument('--dest-csv', action='store_const', const=',', default='\t',
                        dest='dest_delim', help='Signal that the destination file is a CSV.')
    parser.add_argument('--overwrite-terms', action='store_true',
                        help='If a matching location in the destination file already contains '
                             'some location terms, overwrite them with the terms from the source '
                             'file.')
    parser.add_argument('--temp', action='store_true',
                        help="Instead of overwriting the existing destination file, write to a new"
                             " file named '[dest_file].temp'.")

    args = parser.parse_args()

    return args


def main():
    args = parse_args()

    # Keys will be tuples of lat lon and values will be dicts mapping
    # each term below to its corresponding value.
    locations = {}

    # We will write to this instead of overwriting the existing
    # destination file.
    temp_filename = args.dest_file + '.temp'

    # The column headings of the location terms to copy.
    terms = (
        'Characteristics [Collection site (VBcv:0000831)]',
        'Term Accession Number {Characteristics [Collection site (VBcv:0000831)]}',
        'Characteristics [Collection site location (VBcv:0000698)]',
        'Characteristics [Collection site village (VBcv:0000829)]',
        'Characteristics [Collection site locality (VBcv:0000697)]',
        'Characteristics [Collection site suburb (VBcv:0000845)]',
        'Characteristics [Collection site city (VBcv:0000844)]',
        'Characteristics [Collection site county (VBcv:0000828)]',
        'Characteristics [Collection site district (VBcv:0000699)]',
        'Characteristics [Collection site province (VBcv:0000700)]',
        'Characteristics [Collection site country (VBcv:0000701)]'
    )

    with open(args.source_file) as source_f:
        column_names = get_column_names(source_f, args.source_delim)
        source_csv = csv.DictReader(source_f, fieldnames=column_names,
                                    delimiter=args.source_delim)

        for row in source_csv:
            location = (
                row['Characteristics [Collection site latitude (VBcv:0000817)]'],
                row['Characteristics [Collection site longitude (VBcv:0000816)]']
            )

            # If the location is new, store the term values.
            if location not in locations:
                locations[location] = {}

                # Loop through each term and store its value.
                for term in terms:
                    if term in row:
                        locations[location][term] = row[term]

    with open(args.dest_file) as dest_f, open(temp_filename, 'w') as temp_f:
        column_names = get_column_names(dest_f, args.dest_delim)
        dest_csv = csv.DictReader(dest_f, fieldnames=column_names, delimiter=args.dest_delim)
        temp_csv = csv.DictWriter(temp_f, fieldnames=column_names, delimiter=args.dest_delim)

        for row in dest_csv:
            location = (
                row['Characteristics [Collection site latitude (VBcv:0000817)]'],
                row['Characteristics [Collection site longitude (VBcv:0000816)]']
            )

            # If the location matches a location from the source file,
            # continue.
            if location in locations:
                write_terms = True

                # If we don't want to overwrite terms, check to see
                # if a term is already filled in.
                if not args.overwrite_terms:
                    for term in terms:
                        if term in row and row[term]:
                            write_terms = False
                            break

                if write_terms:
                    for term in terms:
                        if term in row and term in locations[location]:
                            row[term] = locations[location][term]

            temp_csv.writerow(row)

        # Remove qualifiers from column names that we added them to
        # to return to the original headings.
        for i in range(len(column_names)):
            name = column_names[i]
            qualified_terms = ('Term Source Ref', 'Term Accession Number')

            for term in qualified_terms:
                if name.startswith(term):
                    name = term

            column_names[i] = name

        # Go to the beginning of the file and write the header row.
        temp_f.seek(0)
        temp_f.write(args.dest_delim.join(column_names) + '\n')

    # If we don't want to leave it as a temp file, overwrite the
    # destination file.
    if not args.temp:
        os.rename(temp_filename, args.dest_file)


def get_column_names(file, delimiter):
    """Gets columns names of a delimited file.

    This function does not return all column names exactly as they are
    in the file.  Some ISA-Tab columns come after ontology term columns
    and give information about those terms.  Such columns have identical
    names within the sheet; this function adds the column name that
    each such column describes to the column's own name to make it
    unique.  The function also strips quotes and whitespace from the
    ends of each name.
    """
    # Parse the first line to get column headings.
    column_names = file.readline().split(delimiter)

    # Clean up the column names.
    for i in range(len(column_names)):
        # Strip whitespace from both ends of the name.
        name = column_names[i].strip()

        # If the name has quotes on both ends, remove them.
        if name[0] == '"' and name[-1] == '"':
            name = name[1:-1]

        # If the name is a term that goes with another term, add the
        # name of the other term in brackets as a qualifier.
        if name == 'Term Source Ref':
            name += ' {' + column_names[i - 1] + '}'

        if name == 'Term Accession Number':
            name += ' {' + column_names[i - 2] + '}'

        column_names[i] = name

    # Reset the file pointer to the beginning.
    file.seek(0)

    return column_names


if __name__ == '__main__':
    main()
