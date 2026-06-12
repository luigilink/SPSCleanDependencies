@{
    # Settings consumed by Invoke-ScriptAnalyzer in CI and the local lint task.
    #
    # PSUseSingularNouns is excluded because the public function
    # Get-SPSMissingServerDependencies must keep its current (plural) name
    # for backward compatibility with existing callers, documentation, and
    # the wiki. Attribute-based per-function suppression is unreliable for
    # this rule, so we exclude it project-wide.
    ExcludeRules = @(
        'PSUseSingularNouns'
    )
}
