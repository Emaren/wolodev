package wolodev_test

import (
	"testing"

	"github.com/stretchr/testify/require"
	keepertest "wolodev/testutil/keeper"
	"wolodev/testutil/nullify"
	"wolodev/x/wolodev"
	"wolodev/x/wolodev/types"
)

func TestGenesis(t *testing.T) {
	genesisState := types.GenesisState{
		Params: types.DefaultParams(),

		// this line is used by starport scaffolding # genesis/test/state
	}

	k, ctx := keepertest.WolodevKeeper(t)
	wolodev.InitGenesis(ctx, *k, genesisState)
	got := wolodev.ExportGenesis(ctx, *k)
	require.NotNil(t, got)

	nullify.Fill(&genesisState)
	nullify.Fill(got)

	// this line is used by starport scaffolding # genesis/test/assert
}
