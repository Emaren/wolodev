package keeper_test

import (
	"testing"

	"github.com/stretchr/testify/require"
	testkeeper "wolodev/testutil/keeper"
	"wolodev/x/wolodev/types"
)

func TestGetParams(t *testing.T) {
	k, ctx := testkeeper.WolodevKeeper(t)
	params := types.DefaultParams()

	k.SetParams(ctx, params)

	require.EqualValues(t, params, k.GetParams(ctx))
}
