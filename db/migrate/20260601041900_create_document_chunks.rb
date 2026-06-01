class CreateDocumentChunks < ActiveRecord::Migration[7.2]
  def change
    create_table :document_chunks do |t|
      t.references :document, null: false, foreign_key: true
      t.text       :content,     null: false
      t.integer    :chunk_index, null: false
      t.vector     :embedding,   limit: 1536
      t.jsonb      :metadata,    null: false, default: {}
      t.timestamps
    end

    add_index :document_chunks, [:document_id, :chunk_index], unique: true

    # IVFFlat index for approximate nearest-neighbor cosine search.
    # The `lists` parameter controls the number of k-means centroids used during
    # index build. Rule of thumb: lists ≈ sqrt(num_rows). The starting value of
    # 100 assumes the system will grow to ~10k chunks. When the row count grows
    # ~10x, rebuild with REINDEX (or drop + recreate) with a larger `lists` value.
    add_index :document_chunks, :embedding,
              using: :ivfflat,
              opclass: :vector_cosine_ops,
              name: "index_document_chunks_on_embedding_ivfflat"
  end
end
