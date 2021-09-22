# --
# Kernel/System/ImportExport/ObjectBackend/Group.pm
# Copyright (C) 2021 Othmar Wigger <othmar.wigger@terreactive.ch>
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::Group;

use strict;
use warnings;
use Kernel::System::Valid;
use Kernel::System::Queue;
use Kernel::System::Group;
use Time::Local;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.0 $) [1];

our @ObjectDependencies = (
    'Kernel::System::ImportExport',
    'Kernel::System::Queue',
    'Kernel::System::Group',
    'Kernel::System::Log',
    'Kernel::Config'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub ObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed object
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => 'Need UserID!' );
        return;
    }

    my %Validlist = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();

    my $Attributes = [
        {
            Key   => 'DefaultValid',
            Name  => 'Default Validity',
            Input => {
                Type         => 'Selection',
                Data         => \%Validlist,
                Required     => 1,
                Translation  => 1,
                PossibleNone => 0,
                ValueDefault => 1,
            },
        },
    ];

    return $Attributes;
}

=item MappingObjectAttributesGet()

get the mapping attributes of an object as array/hash reference

    my $Attributes = $ObjectBackend->MappingObjectAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub MappingObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );
    my @ElementList = qw{};
    for my $Parameter (
        qw(Name Comment Validity)
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

        # required mapping-elements
        if ( $Parameter eq 'Name' ) {
            $CurrAttribute = {
                Key   => $Parameter,
                Value => "$Parameter (required for import)",
            };
        }
        push( @ElementList, $CurrAttribute );
    }

    my $Attributes = [
        {
            Key   => 'Key',
            Name  => 'Key',
            Input => {
                Type         => 'Selection',
                Data         => \@ElementList,
                Required     => 1,
                Translation  => 0,
                PossibleNone => 1,
            },
        },
        {
            Key   => 'Identifier',
            Name  => 'Identifier',
            Input => { Type => 'Checkbox', },
        },
    ];

    return $Attributes;
}

=item SearchAttributesGet()

get the search object attributes of an object as array/hash reference

    my $AttributeList = $ObjectBackend->SearchAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub SearchAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    return;
}

sub ExportDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check object data
    if ( !$ObjectData || ref $ObjectData ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No object data found for the template id $Param{TemplateID}",
        );
        return;
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('Kernel::System::ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check the mapping list
    if ( !$MappingList || ref $MappingList ne 'ARRAY' || !@{$MappingList} ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return;
    }

    # create the mapping object list
    my @MappingObjectList;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData =
            $Kernel::OM->Get('Kernel::System::ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            );

        # check mapping object data
        if ( !$MappingObjectData || ref $MappingObjectData ne 'HASH' ) {

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for the template id $Param{TemplateID}",
            );
            return;
        }

        push( @MappingObjectList, $MappingObjectData );
    }

    # export group ...
    my %GroupDataList = $Kernel::OM->Get('Kernel::System::Group')->GroupDataList();
    my @ExportData;
    for my $GroupData ( values(%GroupDataList) ) {
        
        # prepare validity...
        if ( $GroupData->{ValidID} ) {
            $GroupData->{Validity} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
                ValidID => $GroupData->{ValidID},
            );
        }

        # extract project number from name: this will be our key while renaming a group
        $GroupData->{Name} =~ m/^([\d.]*)/;
        $GroupData->{ProjectID} = $1;

        my @CurrRow;
        for my $MappingObject (@MappingObjectList) {
            my $Key = $MappingObject->{Key};
            if ( !$Key ) {
                push @CurrRow, '';
            }
            else {
                push( @CurrRow, $GroupData->{$Key} || '' );
            }
        }
        push @ExportData, \@CurrRow;

    }
    return \@ExportData;
}

sub ImportDataSave {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID ImportDataRow UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return ( undef, 'Failed' );
        }
    }

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    # check import data row
    if ( ref $Param{ImportDataRow} ne 'ARRAY' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'ImportDataRow must be an array reference',
        );
        return ( undef, 'Failed' );
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check object data
    if ( !$ObjectData || ref $ObjectData ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No object data found for the template id $Param{TemplateID}",
        );
        return ( undef, 'Failed' );
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('Kernel::System::ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check the mapping list
    if ( !$MappingList || ref $MappingList ne 'ARRAY' || !@{$MappingList} ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return ( undef, 'Failed' );
    }

    # create the mapping object list
    my @MappingObjectList;
    my %Identifier;
    my $Counter     = 0;
    my %NewGroupData = qw{};
    my $GroupKey     = "";

    #--------------------------------------------------------------------------
    #BUILD MAPPING TABLE...
    my $IsHeadline = 1;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData =
            $Kernel::OM->Get('Kernel::System::ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            );

        # check mapping object data
        if ( !$MappingObjectData || ref $MappingObjectData ne 'HASH' ) {

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for template id $Param{TemplateID}",
            );
            return ( undef, 'Failed' );
        }

        push( @MappingObjectList, $MappingObjectData );
        if (
            $MappingObjectData->{Identifier}
            && $Identifier{ $MappingObjectData->{Key} }
            )
        {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Can't import this entity. "
                    . "'$MappingObjectData->{Key}' has been used multiple "
                    . "times as identifier (line $Param{Counter}).!",
            );
        }
        elsif ( $MappingObjectData->{Identifier} ) {
            $Identifier{ $MappingObjectData->{Key} } =
                $Param{ImportDataRow}->[$Counter];
            $GroupKey = $MappingObjectData->{Key};
        }
        $NewGroupData{ $MappingObjectData->{Key} } =
            $Param{ImportDataRow}->[$Counter];
        $Counter++;
    }

    #--------------------------------------------------------------------------
    #DO THE IMPORT...
    # lookup Valid-ID...

    if ( !$NewGroupData{ValidID} && $NewGroupData{Validity} ) {
        $NewGroupData{ValidID} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
            Valid => $NewGroupData{Validity}
        );
    }

    # $ukey is a uniqe identifier; decides whether we update or create
    my ($ukey) = $NewGroupData{Name} =~ /^([^\s]+)/;

    # search existing groups
    my $NewGroup = 1;
    my %Groups = $GroupObject->GroupList();
    while (my ($GroupID, $GroupName) = each (%Groups)) {
        $GroupName =~ /^([^\s]+)/;
        if ($ukey eq $1) {
            $NewGroupData{ID} = $GroupID;
            $NewGroup = 0;
            last;
        }
    }

    my $Result     = 0;
    my $ReturnCode = "";    # Created | Changed | Failed

    if ($NewGroup) {
        if ($NewGroupData{Validity} eq "valid"){           
            # create new group
            delete $NewGroupData{ID};
            $Result = $GroupObject->GroupAdd(
                %NewGroupData,
                UserID => $Param{UserID},
            );
            if ( !$Result ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "ImportDataSave: adding Group ("
                        . $NewGroupData{Name}
                        . ") failed (line $Param{Counter}).",
                );
            }
            else {
                $ReturnCode = "Created";
            }
        }
        else {
            $Result = 1;
            $ReturnCode = "Unchanged";
        }
    }
    else {
        # get old group data
        my %GroupData = $GroupObject->GroupGet(
            ID => $NewGroupData{ID},
        );
        # has anything changed?
        my $UpdateGroup = 0;
        for ("Name", "Comment", "ValidID") {
            $UpdateGroup = 1 if ($GroupData{$_} ne $NewGroupData{$_});
        }

        if ($UpdateGroup) {
            # update existing group
            $Result = $GroupObject->GroupUpdate(
                %NewGroupData,
                UserID => $Param{UserID},
            );

            if ( !$Result ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "ImportDataSave: updating Group ("
                        . $NewGroupData{Name}
                        . ") failed (line $Param{Counter}).",
                );
            }
            else {
                $ReturnCode = "Changed";
            }
        }
        else {
            $Result = 1;
            $ReturnCode = "Unchanged";
        }
    }
    return ( $Result, $ReturnCode );
}

1;
