# --
# GroupImportExport.pm - code run during package de-/installation
# Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Ricky(dot)Kaiser(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Anna(dot)Litvinova(at)cape(dash)it(dot)de
#
# --
# $Id: GroupImportExport.pm,v 1.8 2015/09/07 15:29:04 tlange Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl-2.0.txt.
# --

package var::packagesetup::GroupImportExport;

use strict;
use warnings;

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.8 $) [1];

our @ObjectDependencies = (
    'Kernel::System::ImportExport',
    'Kernel::System::Group',
    'Kernel::System::Log',
    'Kernel::Config'
);

=head1 NAME

GroupImportExport.pm - code to excecute during package installation

=head1 SYNOPSIS

All functions

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::Time;
    use Kernel::System::DB;
    use Kernel::System::XML;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject    = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $TimeObject = Kernel::System::Time->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $XMLObject = Kernel::System::XML->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        DBObject     => $DBObject,
        MainObject   => $MainObject,
    );
    my $CodeObject = var::packagesetup::GroupImportExport.pm->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
        TimeObject   => $TimeObject,
        DBObject     => $DBObject,
        XMLObject    => $XMLObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item CodeInstall()

run the code install part

    my $Result = $CodeObject->CodeInstall();

=cut

sub CodeInstall {
    my ( $Self, %Param ) = @_;

    $Self->_CreateMappings();

    return 1;
}

=item CodeReinstall()

run the code reinstall part

    my $Result = $CodeObject->CodeReinstall();

=cut

sub CodeReinstall {
    my ( $Self, %Param ) = @_;

    $Self->_CreateMappings();

    return 1;
}

=item CodeUpgrade()

run the code upgrade part

    my $Result = $CodeObject->CodeUpgrade();

=cut

sub CodeUpgrade {
    my ( $Self, %Param ) = @_;

    $Self->_CreateMappings();
    
    return 1;
}

=item CodeUninstall()

run the code uninstall part

    my $Result = $CodeObject->CodeUninstall();

=cut

sub CodeUninstall {
    my ( $Self, %Param ) = @_;

    $Self->_RemoveRelatedMappings();

    return 1;
}

sub _RemoveRelatedMappings() {

    my ( $Self, %Param ) = @_;

    my $TemplateList = $Kernel::OM->Get('Kernel::System::ImportExport')->TemplateList(
        Object => 'Group',
        Format => 'CSV',
        GroupID => 1,
    );

    if ( ref($TemplateList) eq 'ARRAY' && @{$TemplateList} ) {
        $Kernel::OM->Get('Kernel::System::ImportExport')->TemplateDelete(
            TemplateID => $TemplateList,
            GroupID     => 1,
        );
    }

    return 1;
}

sub _CreateMappings() {
    my ( $Self, %Param ) = @_;

    my $TemplateObject = "Group";
    my $TemplateName   = "Group - ImportExport (auto-created map)";
    my %TemplateList   = ();

    # get config option
    my $ForceCSVMappingConfiguration = $Kernel::OM->Get('Kernel::Config')->Get(
        'GroupImport::ForceCSVMappingRecreation'
    ) || '0';

    #---------------------------------------------------------------------------
    # add a template user
    # get list of all templates
    my $TemplateListRef = $Kernel::OM->Get('Kernel::System::ImportExport')->TemplateList(
        Object => $TemplateObject,
        Format => 'CSV',
        GroupID => 1,
    );

    # get data for each template and build hash with key = template name; value = template ID
    if ( $TemplateListRef && ref($TemplateListRef) eq 'ARRAY' ) {
        for my $CurrTemplateID ( @{$TemplateListRef} ) {
            my $TemplateDataRef = $Kernel::OM->Get('Kernel::System::ImportExport')->TemplateGet(
                TemplateID => $CurrTemplateID,
                GroupID     => 1,
            );
            if (
                $TemplateDataRef
                && ref($TemplateDataRef) eq 'HASH'
                && $TemplateDataRef->{Object}
                && $TemplateDataRef->{Name}
                )
            {
                $TemplateList{ $TemplateDataRef->{Object} . '::' . $TemplateDataRef->{Name} }
                    = $CurrTemplateID;
            }
        }
    }

    #---------------------------------------------------------------------------
    # add a template user
    my $TemplateID;

    # check if template already exists...
    if ( $TemplateList{ $TemplateObject . '::' . $TemplateName } ) {
        if ($ForceCSVMappingConfiguration) {

            # delete old template
            $Kernel::OM->Get('Kernel::System::ImportExport')->TemplateDelete(
                TemplateID => $TemplateList{ $TemplateObject . '::' . $TemplateName },
                GroupID     => 1,
            );
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "CSV mapping deleted for re-creation <"
                    . $TemplateName
                    . ">.",
            );

            # create new template
            $TemplateID = $Kernel::OM->Get('Kernel::System::ImportExport')->TemplateAdd(
                Object  => $TemplateObject,
                Format  => 'CSV',
                Name    => $TemplateName,
                Comment => "Automatically created during GroupImportExport installation",
                ValidID => 1,
                GroupID  => 1,
            );
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "CSV mapping already exists and not re-created <"
                    . $TemplateName
                    . ">.",
            );
            return 1;
        }
    }
    else {

        # create new template
        $TemplateID = $Kernel::OM->Get('Kernel::System::ImportExport')->TemplateAdd(
            Object  => $TemplateObject,
            Format  => 'CSV',
            Name    => $TemplateName,
            Comment => "Automatically created during GroupImportExport installation",
            ValidID => 1,
            GroupID  => 1,
        );
    }

    #-----------------------------------------------------------------------
    # create attribute mapping...
    my @ElementList = qw{};
    for my $Parameter (
        qw(Name,ProjectID,Validity)
        )
    {
        my $CurrAttribute = {
            Key   => $Parameter,
            Value => $Parameter,
        };

        # if ValidID is available - offer Valid instead..
        if ( $Parameter eq 'ValidID' ) {
            $CurrAttribute = { Key => 'Valid', Value => 'Validity', };
        }

        push( @ElementList, $CurrAttribute );

    }

    # for CustomQueues
    for my $Parameter ( 0 .. 9 ) {
        $Parameter = 'CustomQueue' . sprintf( "%03d", $Parameter );
        my $CurrAttribute = {
            Key   => $Parameter,
            Value => $Parameter,
        };
        push( @ElementList, $CurrAttribute );
    }

    # for roles
    for my $Parameter ( 0 .. 9 ) {
        $Parameter = 'Role' . sprintf( "%03d", $Parameter );
        my $CurrAttribute = {
            Key   => $Parameter,
            Value => $Parameter,
        };
        push( @ElementList, $CurrAttribute );
    }

    my $ExportDataSets = [
        {
            SourceExportData => {
                FormatData => {
                    ColumnSeparator      => 'Semicolon',
                    Charset              => 'UTF-8',
                    IncludeColumnHeaders => 1,
                },

                MappingObjectData => \@ElementList,
                ExportDataGet     => {
                    TemplateID => $TemplateID,
                    GroupID     => 1,
                },
            },
        }
    ];

    # get object attributes
    my $ObjectAttributeList = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectAttributesGet(
        TemplateID => $ExportDataSets->[0]->{SourceExportData}->{ExportDataGet}->{TemplateID},
        GroupID     => 1,
    );

    # ----------------------------------------------------------------------
    # run general ExportDataGet...
    EXPORTDATASET:
    for my $CurrentExportDataSet ( @{$ExportDataSets} ) {

        # check SourceExportData attribute
        if (
            !$CurrentExportDataSet->{SourceExportData}
            || ref $CurrentExportDataSet->{SourceExportData} ne 'HASH'
            )
        {

            next EXPORTDATASET;
        }

        # set the format data
        if (
            $CurrentExportDataSet->{SourceExportData}->{FormatData}
            && ref $CurrentExportDataSet->{SourceExportData}->{FormatData} eq 'HASH'
            && $CurrentExportDataSet->{SourceExportData}->{ExportDataGet}->{TemplateID}
            )
        {

            # save format data
            $Kernel::OM->Get('Kernel::System::ImportExport')->FormatDataSave(
                TemplateID =>
                    $CurrentExportDataSet->{SourceExportData}->{ExportDataGet}->{TemplateID},
                FormatData => $CurrentExportDataSet->{SourceExportData}->{FormatData},
                GroupID     => 1,
            );
        }

        # set the mapping object data
        if (
            $CurrentExportDataSet->{SourceExportData}->{MappingObjectData}
            && ref $CurrentExportDataSet->{SourceExportData}->{MappingObjectData} eq 'ARRAY'
            && $CurrentExportDataSet->{SourceExportData}->{ExportDataGet}->{TemplateID}
            )
        {

            # delete all existing mapping data
            $Kernel::OM->Get('Kernel::System::ImportExport')->MappingDelete(
                TemplateID =>
                    $CurrentExportDataSet->{SourceExportData}->{ExportDataGet}->{TemplateID},
                GroupID => 1,
            );

            # add the mapping object rows
            MAPPINGOBJECTDATA:
            for my $MappingObjectData (
                @{ $CurrentExportDataSet->{SourceExportData}->{MappingObjectData} }
                )
            {

                # add a new mapping row
                my $MappingID = $Kernel::OM->Get('Kernel::System::ImportExport')->MappingAdd(
                    TemplateID =>
                        $CurrentExportDataSet->{SourceExportData}->{ExportDataGet}
                        ->{TemplateID},
                    GroupID => 1,
                );

                # add the mapping object data
                $Kernel::OM->Get('Kernel::System::ImportExport')->MappingObjectDataSave(
                    MappingID         => $MappingID,
                    MappingObjectData => $MappingObjectData,
                    GroupID            => 1,
                );
            }
        }

    }

    return 1;

}

1;
