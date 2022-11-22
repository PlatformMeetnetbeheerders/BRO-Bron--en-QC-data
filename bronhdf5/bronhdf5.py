"""
    bronhdf5.py

    Copyright (c) 2022 Giel van Bergen <g.van.bergen@gelderland.nl>
    Utilities for writing and reading BRO-HDF5-files.

    Published by Provincie Gelderland, under the CC-BY Public License ( Creative Commons Attribution 4.0 International).
"""
import warnings
from typing import Tuple

import numpy as np
import h5py
from pandas import DataFrame, Series

BRON_VERSION = (2, 0)


def write_df(hdfgroup: h5py.Group, df: DataFrame):
    """
    Write Dataframe df to hdfgroup.

    :param hdfgroup: HDFGroup where under which the table in `df` will be stored.
    :type hdfgroup: h5py.Group
    :param df: Single column of a DataFrame.
    :type df: DataFrame
    """
    write_df_metadata(hdfgroup, df)

    for (colname, col) in df.iteritems():
        write_df_column(hdfgroup, col)


def infer_column_matlab_type(col: Series) -> bytes:
    """
    Infer the 'matlab_type' of a column.

    :param col: Single column of a DataFrame.
    :type col: Series
    :return: Name of the matlab_type
    :rtype: bytes
    """
    if any(isinstance(z, DataFrame) for z in col):
        ml_type = b"table"
    elif col.dtype != np.dtype("O"):
        ml_type = col.dtype.name.encode("utf-8")  # change to "bytes"
    else:
        col_dtypes = set(np.dtype(type(z)) for z in col)
        if len(set(col_dtypes)) == 1:
            ml_type = np.dtype(type(col[0])).name.encode("utf-8")
        else:
            raise ValueError(f"Unable to infer matlab_type of column {col}")
    if ml_type == b"bytes":
        ml_type = b"cellstr"
    return ml_type


def write_df_column(hdfgroup: h5py.Group, col: Series) -> None:
    """
    Write the column `col` as dataset `col.name` under the HDF5 Group `hdfgroup`

    :param hdfgroup: Group under which the dataset will be stored.
    :type hdfgroup: h5py.Group
    :param col: column
    :type col: Series
    """
    ml_type = infer_column_matlab_type(col)
    if ml_type == b"table":
        col_group = hdfgroup.create_group(col.name)
        # [BYTES_ARRAY] Wrap in np.array, otherwise the attribute will be stored as a character string instead of bytes.
        col_group.attrs.create("matlab_type", np.array(b"table"))
        for (i, z) in enumerate(col, start=1):  # one-based indexing!
            write_df(col_group.create_group(f"Element{i}"), z)
        write_df_metadata(col_group, DataFrame(col))
    else:
        dataset = hdfgroup.create_dataset(col.name, data=col.values)
        dataset.attrs.create("matlab_type", np.array(ml_type))


def write_df_metadata(hdfgroup: h5py.Group, df: DataFrame) -> None:
    """Write DataFrame metadata to an hdfgroup

    :param hdfgroup: Group to store the metadata in.
    :type hdfgroup: h5py.Group
    :param df:  
    :type df: DataFrame with VariableUnits and VariableDescriptions fields.
    """

    # See comment BYTES_ARRAY for the reason for np.array
    hdfgroup.attrs.create("matlab_type", np.array(b"table"))
    colnames = list(df.columns)
    dataset = hdfgroup.create_dataset("VariableNames", data=colnames)
    dataset.attrs.create("matlab_type", np.array(b"cellstr"))

    try:
        vd = df.VariableDescriptions
    except AttributeError:
        vd = np.array([], dtype=bytes)

    dataset = hdfgroup.create_dataset("VariableDescriptions", data=vd)
    dataset.attrs.create("matlab_type", np.array(b"cellstr"))

    try:
        vu = df.VariableUnits
    except AttributeError:
        vu = np.array([], dtype=bytes)

    dataset = hdfgroup.create_dataset("VariableUnits", data=vu)
    dataset.attrs.create("matlab_type", np.array(b"cellstr"))


class GMW:
    """TODO: Add GMW documentation."""
    # Note: Listed in alphabetic order.
    History: DataFrame
    Tube: DataFrame
    Well: DataFrame

    FIELDS: Tuple[str, str, str] = ("History", "Tube", "Well")

    def __init__(self, *, History: DataFrame, Tube: DataFrame, Well: DataFrame):
        self.History = History
        self.Tube = Tube
        self.Well = Well

    def write(self, hdfgroup: h5py.Group):
        for field_name in self.FIELDS:
            field_group: h5py.Group = hdfgroup.create_group(field_name)
            write_df(field_group, getattr(self, field_name))


def write_gmws_to_bron2(hdfgroup: h5py.Group, gmws: dict) -> None:
    """Write GMWs to BRO-HDF5 file containing a GMW object.

    :param hdfgroup: Location to write the GMWs to.
    :param gmws: contains GMWs, each GMW gets written to hdfgroup[key]
    """
    hdfgroup.attrs.create("BRON_VERSION", BRON_VERSION)
    for (group, gmw) in gmws.items():
        gmw.write(hdfgroup.create_group(group))


def _check_bron_version(hdfgroup: h5py.Group) -> None:
    """ Check if the HDF5-file has a Bron-version compatible with this library.
    Raise an error if not.

    :param hdfgroup: Top-level HDF5-group of the corresponding file.
    :raise  KeyError: If there is no attribute BRON_VERSION in hdfgroup`
    :raise  NotImplementedError: The atttribute BRON_vERSION has a different major version than this supports.
    """
    if "BRON_VERSION" not in hdfgroup.attrs:
        raise KeyError(
            f"Can't locate attribute BRON_VERSION in {hdfgroup.name}. (Very old bron-file?)"
        )
    elif hdfgroup.attrs["BRON_VERSION"][0] != BRON_VERSION[0]:
        raise NotImplementedError(
            f"The HDF5-file has BRON_VERSION {hdfgroup.attrs['BRON_VERSION']}, only {BRON_VERSION} is supported."
        )


def read_bron2_to_gmws(hdfgroup: h5py.Group) -> dict:
    """Read a custom BronHDF5 file containing a GMW object.

    :param hdfgroup: HDF5 Group under which to the GMWs are stored.
    :return: dict containing the GMWs in hdfgroup.
    """

    _check_bron_version(hdfgroup)

    gkeys = sorted(hdfgroup.keys())
    try:
        # Version [2, 0]: The group keys are integers (as strings), in which case sort them by integer value instead of lexicographic value.
        # Note: The integer keys use one-based indexing, i.e. start at 1 instead of 0
        gkeys = sorted(hdfgroup.keys(), key=int)
    except ValueError:
        pass
    gmws = {}
    for k in gkeys:
        group = hdfgroup[k]
        history = parse_bronhdf(group["History"])
        tube = parse_bronhdf(group["Tube"])
        well = parse_bronhdf(group["Well"])
        gmws[k] = GMW(History=history, Tube=tube, Well=well)
    return gmws


# NOTE: Since DataFrames don't support Properties.Variable{Units,Descriptions}, we put them in the first two rows.
def parse_bronhdf(hdfgroup: h5py.Group) -> DataFrame:
    """Parse an HDF5-group and convert to a DataFrame

    :param hdfgroup: group under which a DataFrame has been stored
    :return: The Dataframe saved in hdfgroup, 
    :rtype: DataFrame with two extra attributes: VariableUnits and VariableDescriptions, containing
             the variable type, and a description of the variable.
    """
    colnames = hdfgroup["VariableNames"][:]

    # If the stored table was empty, simply return an empty DataFrame.
    # (Python note: collections evaluate to a falsey value if empty.)
    if len(colnames) == 0 or (len(colnames) == 1 and colnames[0] == b"Var1"):
        empty_df = DataFrame([])
        # Pandas gives a warning if we add our own fields, do it anyways but silence the warning.
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            empty_df.VariableDescriptions = []
            empty_df.VariableUnits = []

        return empty_df

    metadata = {}
    for metaname in ("VariableDescriptions", "VariableUnits"):
        data = hdfgroup[metaname][:]
        if len(data) > 0:
            metadata[metaname] = data.astype(bytes)
        else:
            metadata[metaname] = np.array([b""] * len(colnames))

    for colname in colnames:
        if isinstance(hdfgroup[colname], h5py.Dataset):
            nrows = hdfgroup[colname].size
            break
    else:  # Code in 'else' of a 'for'-block is only executed if break wasn't encountered.
        # There are no Bron-models where the dataframes consists of only nested dataframes.
        raise Exception(f"Bad Bron datamodel in {hdfgroup.name = } with {colnames = }")

    df = DataFrame(columns=colnames)
    for colname in colnames:
        ml_type = hdfgroup[colname].attrs["matlab_type"]
        if ml_type != b"table" and ml_type != "table":
            df[colname] = hdfgroup[colname][:]
        else:
            colcontents = [
                parse_bronhdf(hdfgroup[colname][f"Element{i_row}"])
                for i_row in range(1, nrows + 1)  # (one-based indexing in BRO-HDF5)
            ]
            df[colname] = colcontents

    # Pandas gives a warning if we add our own fields, do it anyways but silence the warning.
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        df.VariableDescriptions = metadata["VariableDescriptions"]
        df.VariableUnits = metadata["VariableUnits"]

    return df
