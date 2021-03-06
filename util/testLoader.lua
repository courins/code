require 'torch'
require 'hdf5'

utils = require 'util.utils'

DataLoader = torch.class('DataLoader')


function DataLoader:__init(kwargs)
  h5_file = utils.get_kwarg(kwargs, 'input_h5')
  self.batch_size = utils.get_kwarg(kwargs, 'batch_size')
  self.seq_length = utils.get_kwarg(kwargs, 'seq_length')
  N, T = self.batch_size, self.seq_length

  -- Just slurp all the data into memory
  splits = {}
  f = hdf5.open(h5_file, 'r')
  splits.train = f:read('/train'):all()
  splits.val = f:read('/val'):all()
  splits.test = f:read('/test'):all()

  self.x_splits = {}
  self.y_splits = {}
  self.split_sizes = {}
  for split, v in pairs(splits) do
    num = v:nElement()
    extra = num % (N * T)

    -- Ensure that `vy` is non-empty
    if extra == 0 then
      extra = N * T
    end

    -- Chop out the extra bits at the end to make it evenly divide
    vx = v[{{1, num - extra}}]:view(N, -1, T):transpose(1, 2):clone()
    vy = v[{{2, num - extra + 1}}]:view(N, -1, T):transpose(1, 2):clone()

    self.x_splits[split] = vx
    self.y_splits[split] = vy
    self.split_sizes[split] = vx:size(1)
  end

  self.split_idxs = {train=1, val=1, test=1}
end


function DataLoader:nextBatch(split)
  idx = self.split_idxs[split]
  assert(idx, 'invalid split ' .. split)
  x = self.x_splits[split][idx]
  y = self.y_splits[split][idx]
  if idx == self.split_sizes[split] then
    self.split_idxs[split] = 1
  else
    self.split_idxs[split] = idx + 1
  end
  return x, y
end

