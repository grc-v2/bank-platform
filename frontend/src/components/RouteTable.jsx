// Chỉ thẻ gateway có bảng này — nó là thứ làm thẻ gateway đáng nhìn.
export default function RouteTable({ routes }) {
  return (
    <table className="routes">
      <thead>
        <tr>
          <th>Route</th>
          <th>Path</th>
          <th>Đích</th>
        </tr>
      </thead>
      <tbody>
        {routes.map((r) => (
          <tr key={r.id}>
            <td>{r.id}</td>
            <td>{r.paths.join(', ')}</td>
            <td>{r.target}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}
