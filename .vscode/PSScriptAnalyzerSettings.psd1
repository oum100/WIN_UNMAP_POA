@{
    Severity = @('Error', 'Warning')
    IncludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidUsingPositionalParameters',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseSingularNouns',
        'PSUseShouldProcessForStateChangingFunctions'
    )
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns'
    )
}
